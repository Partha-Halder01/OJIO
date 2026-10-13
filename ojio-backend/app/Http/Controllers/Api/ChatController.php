<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ChatMessage;
use App\Models\ChatThread;
use App\Models\Listing;
use App\Services\PushNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ChatController extends Controller
{
    public function threads(Request $request)
    {
        $userId = $request->user()->id;

        $threads = ChatThread::where(function ($q) use ($userId) {
            $q->where('buyer_id', $userId)
                ->orWhere('seller_id', $userId);
        })
            ->whereHas('messages')
            ->with(['listing.primaryImage', 'buyer:id,name,avatar', 'seller:id,name,avatar', 'messages' => function ($q) {
                $q->reorder('id', 'desc')->limit(1);
            }])
            ->withCount(['messages as unread_count' => fn ($q) => $q->where('sender_id', '!=', $userId)->where('is_read', false)])
            ->orderBy('last_message_at', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $threads,
        ]);
    }

    public function messages(Request $request, $threadId)
    {
        $userId = $request->user()->id;

        $thread = ChatThread::where('id', $threadId)
            ->where(function ($q) use ($userId) {
                $q->where('buyer_id', $userId)->orWhere('seller_id', $userId);
            })
            ->with(['listing.primaryImage', 'buyer:id,name,avatar', 'seller:id,name,avatar'])
            ->firstOrFail();

        // Mark unread messages as read
        ChatMessage::where('chat_thread_id', $thread->id)
            ->where('sender_id', '!=', $userId)
            ->update(['is_read' => true]);

        $messages = ChatMessage::where('chat_thread_id', $thread->id)->orderBy('id')->get();

        return response()->json([
            'status' => 'success',
            'thread' => $thread,
            'messages' => $messages,
        ]);
    }

    public function sendMessage(Request $request)
    {
        $request->validate([
            'listing_id' => 'required_without:thread_id|nullable|integer|exists:listings,id',
            'thread_id' => 'required_without:listing_id|nullable|integer|exists:chat_threads,id',
            'message' => 'required|string|max:1000',
        ]);

        $userId = $request->user()->id;
        if (trim($request->message) === '') {
            return response()->json(['message' => 'Please enter a message.'], 422);
        }
        $thread = null;

        // 1. If thread_id provided, use existing thread if user is participant
        if ($request->filled('thread_id')) {
            $thread = ChatThread::where('id', $request->thread_id)
                ->where(function ($q) use ($userId) {
                    $q->where('buyer_id', $userId)->orWhere('seller_id', $userId);
                })
                ->first();

            if (! $thread) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Unauthorized: You are not a participant in this conversation.',
                ], 403);
            }
        }

        // 2. If thread not found yet, use listing_id to find or create thread
        if (! $thread && $request->filled('listing_id')) {
            $listing = Listing::findOrFail($request->listing_id);

            // If user is listing owner, check if existing thread exists with a buyer
            if ($listing->user_id == $userId) {
                return response()->json(['message' => 'Choose an existing buyer conversation to reply.'], 422);
            } else {
                abort_unless($listing->status === 'active' && ! $listing->user->is_blocked, 422, 'This listing is unavailable.');
                $thread = ChatThread::firstOrCreate(
                    [
                        'listing_id' => $listing->id,
                        'buyer_id' => $userId,
                        'seller_id' => $listing->user_id,
                    ],
                    [
                        'last_message_at' => now(),
                    ]
                );
            }
        }

        if (! $thread) {
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid thread or listing reference.',
            ], 400);
        }

        $msg = ChatMessage::create([
            'chat_thread_id' => $thread->id,
            'sender_id' => $userId,
            'message' => trim($request->message),
            'is_read' => false,
        ]);

        $thread->update(['last_message_at' => now()]);

        app(PushNotificationService::class)->notify(
            (int) ((int) $userId === (int) $thread->buyer_id ? $thread->seller_id : $thread->buyer_id),
            'chat', 'New message', 'You have a new message on OJIO.',
            ['thread_id' => (string) $thread->id, 'event_id' => 'chat_'.$msg->id],
        );

        return response()->json([
            'status' => 'success',
            'data' => $msg,
            'thread_id' => $thread->id,
        ], 201);
    }

    public function open(Request $request): JsonResponse
    {
        $data = $request->validate(['listing_id' => 'required|integer|exists:listings,id']);
        $listing = Listing::findOrFail($data['listing_id']);
        abort_if($listing->user_id === $request->user()->id, 422, 'You cannot chat on your own listing.');
        abort_unless($listing->status === 'active' && ! $listing->user->is_blocked, 422, 'This listing is unavailable.');
        $thread = ChatThread::firstOrCreate([
            'listing_id' => $listing->id, 'buyer_id' => $request->user()->id, 'seller_id' => $listing->user_id,
        ], ['last_message_at' => now()]);

        return response()->json(['status' => 'success', 'data' => ['thread_id' => $thread->id]]);
    }
}

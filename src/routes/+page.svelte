<script lang="ts">
	import { onMount, afterUpdate } from 'svelte';
	import api from '$lib/api';
	import type { Message } from '$lib/types/Message';

	let username: string = 'User' + Math.floor(Math.random() * 1000);
	let newMessage: string = '';
	let messages: Message[] = [];
	let chatContainer: HTMLDivElement;

	const scrollToBottom = () => {
		if (chatContainer) {
			chatContainer.scrollTop = chatContainer.scrollHeight;
		}
	};

	const fetchAllMessages = async () => {
		try {
			const response = await api.get('/chat/all', { params: { username } });
			messages = response.data.messages;
			scrollToBottom();
		} catch (error) {
			console.error('Error fetching all messages:', error);
		}
	};

	const fetchNewMessages = async () => {
		try {
			const lastTimestamp = messages.length
				? messages[messages.length - 1].timestamp
				: new Date(0).toISOString();
			const response = await api.get('/chat', {
				params: { username, after: lastTimestamp }
			});
			if (response.data.messages && response.data.messages.length) {
				messages = [...messages, ...response.data.messages];
				scrollToBottom();
			}
		} catch (error) {
			console.error('Error fetching new messages:', error);
		}
	};

	const sendMessage = async () => {
		if (!newMessage.trim()) return;
		try {
			await api.post('/chat', { username, message: newMessage });
			newMessage = '';
			await fetchAllMessages();
			scrollToBottom();
		} catch (error) {
			console.error('Error sending message:', error);
		}
	};

	onMount(() => {
		fetchAllMessages();
		const interval = setInterval(fetchNewMessages, 3000); // polling co 3 sekundy
		return () => clearInterval(interval);
	});

	afterUpdate(() => {
		scrollToBottom();
	});

	async function handleFileDownload(message: Message) {
		try {
			const response = await api.get(`/chat/files/${message.message}`);

			const presignedUrl: string = response.data;

			console.log(`Presigned download link: ${presignedUrl}`);

			const fileResponse = await fetch(presignedUrl, {
				method: 'GET'
			});

			const data = await fileResponse.blob();
			const downloadFileUrl = URL.createObjectURL(data);
			const link = document.createElement('a');
			link.href = downloadFileUrl;
			link.download = message.message;
			document.body.append(link);
			link.click();
			link.remove();
			URL.revokeObjectURL(downloadFileUrl);
		} catch (error) {
			console.error('Error downloading file:', error);
		}
	}

	let fileInput: HTMLInputElement;

	async function handleFileSelect(event: Event & { currentTarget: HTMLInputElement }) {
		const files = event.currentTarget.files;

		if (files && files.length > 0) {
			const file = files[0];
			try {
				const response = await api.post('/chat/files/presign', {
					username,
					filename: file.name,
					contentType: file.type
				});

				const presignedUrl: string = response.data;

				console.log(`Presigned upload link: ${presignedUrl}`);

				await fetch(presignedUrl, {
					method: 'PUT',
					headers: { 'Content-Type': file.type },
					body: file
				});

				await fetchAllMessages();
				scrollToBottom();
			} catch (error) {
				console.error('Error uploading file:', error);
			}
		}
	}
</script>

<div class="mx-auto max-w-2xl p-4">
	<!-- Pole do zmiany nicku -->
	<div class="mb-4 flex items-center">
		<label for="username" class="mr-2 font-semibold">Nickname:</label>
		<input
			id="username"
			type="text"
			autocomplete="off"
			bind:value={username}
			class="rounded border border-gray-300 px-3 py-2"
			placeholder="Enter your nickname"
		/>
	</div>

	<h1 class="mb-4 text-2xl font-bold">Chat Room</h1>

	<!-- Kontener wiadomości z przypiętą referencją -->
	<div
		class="mb-4 h-80 overflow-y-auto rounded border border-gray-300 p-4"
		bind:this={chatContainer}
	>
		{#each messages as msg (msg.timestamp)}
			<div class="mb-2">
				<span class="font-semibold">{msg.username}</span>
				<span class="ml-2 text-sm text-gray-500"
					>{new Date(msg.timestamp).toLocaleTimeString()}</span
				>

				{#if msg.isFile}
					<div class="mt-1">
						<button
							on:click={() => handleFileDownload(msg)}
							class="inline-flex cursor-pointer items-center text-blue-600 hover:text-blue-800 hover:underline"
						>
							<svg class="mr-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
								/>
							</svg>
							📎 {msg.message}
						</button>
					</div>
				{:else}
					<p>{msg.message}</p>
				{/if}
			</div>
		{/each}
	</div>

	<div class="flex space-x-2">
		<input
			type="text"
			bind:value={newMessage}
			class="flex-grow rounded border border-gray-300 px-3 py-2 focus:ring focus:outline-none"
			placeholder="Type your message..."
		/>
		<input type="file" bind:this={fileInput} on:change={handleFileSelect} class="hidden" />
		<button
			on:click={() => fileInput.click()}
			class="flex cursor-pointer items-center rounded bg-gray-500 px-4 py-2 font-semibold text-white hover:bg-gray-600"
			title="Upload file"
			aria-label="Upload file"
		>
			<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path
					stroke-linecap="round"
					stroke-linejoin="round"
					stroke-width="2"
					d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-7.072 7.072A6 6 0 1010.808 21l8.486-8.486M7 9l4 4"
				/>
			</svg>
		</button>
		<button
			on:click={sendMessage}
			class="cursor-pointer rounded bg-blue-500 px-4 py-2 font-semibold text-white hover:bg-blue-600"
		>
			Send
		</button>
	</div>
</div>

export function setupSocketHandlers(io)
{
    // Store secondary camera mappings
    const secondaryCameraMappings=new Map(); // code -> {interviewId, socketId}

    // Store proctor dashboard sockets
    const proctorDashboardSockets=new Set();

    io.on('connection', (socket) =>
    {
        console.log(`User connected: ${socket.id}`);

        // Join proctor dashboard room
        socket.on('join-proctor-dashboard', () =>
        {
            socket.join('proctor-dashboard');
            proctorDashboardSockets.add(socket.id);
            console.log(`Proctor joined dashboard: ${socket.id}`);
        });

        // Join interview room
        socket.on('join-interview', (data) =>
        {
            const {interviewId, userName, role}=data;
            socket.join(interviewId);

            console.log(`${userName} (${role}) joined interview ${interviewId}`);

            // Notify others in the room
            socket.to(interviewId).emit('user-joined', {
                userId: socket.id,
                userName,
                role,
            });

            // Notify proctor dashboard of new session
            io.to('proctor-dashboard').emit('session-update', {
                interviewId,
                type: 'user-joined',
                userName,
                role,
            });
        });

        // Leave interview room
        socket.on('leave-interview', (data) =>
        {
            const {interviewId}=data;
            socket.leave(interviewId);

            socket.to(interviewId).emit('user-left', {
                userId: socket.id,
            });
        });

        // WebRTC signaling - offer
        socket.on('webrtc-offer', (data) =>
        {
            const {offer, to}=data;
            io.to(to).emit('webrtc-offer', {
                offer,
                from: socket.id,
            });
        });

        // WebRTC signaling - answer
        socket.on('webrtc-answer', (data) =>
        {
            const {answer, to}=data;
            io.to(to).emit('webrtc-answer', {
                answer,
                from: socket.id,
            });
        });

        // WebRTC signaling - ICE candidate
        socket.on('webrtc-ice-candidate', (data) =>
        {
            const {candidate, to}=data;
            io.to(to).emit('webrtc-ice-candidate', {
                candidate,
                from: socket.id,
            });
        });

        // Code updates (real-time collaboration)
        socket.on('code-update', (data) =>
        {
            const {interviewId, code, language}=data;
            socket.to(interviewId).emit('code-update', {
                code,
                language,
                from: socket.id,
            });
        });

        // Question updates (interviewer changes question)
        socket.on('question-update', (data) =>
        {
            const {interviewId, question}=data;
            console.log(`Question updated in interview ${interviewId}:`, question.title);
            socket.to(interviewId).emit('question-update', {
                question,
                from: socket.id,
            });
        });

        // Chat messages
        socket.on('chat-message', (data) =>
        {
            const {interviewId, message, userName}=data;
            io.to(interviewId).emit('chat-message', {
                message,
                userName,
                timestamp: new Date(),
                from: socket.id,
            });
        });

        // Proctoring events
        socket.on('proctoring-event', (data) =>
        {
            const {interviewId, event}=data;

            // Notify recruiter about the event
            socket.to(interviewId).emit('proctoring-alert', {
                event,
                timestamp: new Date(),
            });

            // Notify proctor dashboard
            io.to('proctor-dashboard').emit('proctoring-alert', {
                interviewId,
                event,
                timestamp: new Date(),
            });
        });

        // Secondary camera - register mapping
        socket.on('register-secondary-camera', (data) =>
        {
            const {interviewId, code}=data;
            secondaryCameraMappings.set(code, {
                interviewId,
                mainSocketId: socket.id
            });
            console.log(`📱 Secondary camera registered: ${code} for interview ${interviewId}`);
        });

        // Secondary camera - phone connection
        socket.on('connect-secondary-camera', (data) =>
        {
            const {code, status}=data;
            const mapping=secondaryCameraMappings.get(code);

            if (mapping)
            {
                // Store phone socket ID
                mapping.phoneSocketId=socket.id;
                secondaryCameraMappings.set(code, mapping);

                // Notify main device
                io.to(mapping.mainSocketId).emit('secondary-camera-connected', {
                    status,
                    timestamp: new Date()
                });

                console.log(`📱 Secondary camera connected: ${code}`);
            }
        });

        // Secondary camera - receive snapshot
        socket.on('secondary-snapshot', (data) =>
        {
            const {code, snapshot}=data;
            const mapping=secondaryCameraMappings.get(code);

            if (mapping)
            {
                // Forward snapshot to main device and recruiter in the room
                io.to(mapping.mainSocketId).emit('secondary-snapshot', {
                    snapshot,
                    timestamp: new Date()
                });

                // Also send to interview room for recruiter
                socket.to(mapping.interviewId).emit('secondary-snapshot', {
                    snapshot,
                    timestamp: new Date()
                });

                // Remove from proctor dashboard if applicable
                if (proctorDashboardSockets.has(socket.id))
                {
                    proctorDashboardSockets.delete(socket.id);
                }
            }
        });

        // Disconnect
        socket.on('disconnect', () =>
        {
            console.log(`User disconnected: ${socket.id}`);
        });
    });
}

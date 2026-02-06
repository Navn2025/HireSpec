import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import {createServer} from 'http';
import {Server} from 'socket.io';
import interviewRoutes from './routes/interview.js';
import questionRoutes from './routes/questions.js';
import codeExecutionRoutes from './routes/codeExecution.js';
import proctoringRoutes from './routes/proctoring.js';
import aiRoutes from './routes/ai.js';
import practiceRoutes from './routes/practice.js';
import {setupSocketHandlers} from './socket/handlers.js';

dotenv.config();

const app=express();
const httpServer=createServer(app);

const FRONTEND_URL=process.env.FRONTEND_URL||'http://localhost:5173';

const io=new Server(httpServer, {
    cors: {
        origin: FRONTEND_URL,
        methods: ['GET', 'POST'],
        credentials: true,
    },
});

// Middleware
app.use(cors({
    origin: FRONTEND_URL,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    credentials: true,
}));
app.use(express.json());

// Routes
app.use('/api/interview', interviewRoutes);
app.use('/api/questions', questionRoutes);
app.use('/api/code-execution', codeExecutionRoutes);
app.use('/api/proctoring', proctoringRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/practice', practiceRoutes);

// Health check
app.get('/api/health', (req, res) =>
{
    res.json({status: 'ok', message: 'Server is running'});
});

// Setup Socket.IO handlers
setupSocketHandlers(io);

const PORT=process.env.PORT||5000;
httpServer.listen(PORT, () =>
{
    console.log(`🚀 Backend running on http://localhost:${PORT}`);
    console.log(`📡 WebSocket server ready`);
});

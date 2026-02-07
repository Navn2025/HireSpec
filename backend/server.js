// Load environment variables FIRST - must be before other imports
import './config.js';

import express from 'express';
import cors from 'cors';
import {createServer} from 'http';
import {Server} from 'socket.io';
import {initializeDatabase} from './db/database.js';
import interviewRoutes from './routes/interview.js';
import questionRoutes from './routes/questions.js';
import codeExecutionRoutes from './routes/codeExecution.js';
import proctoringRoutes from './routes/proctoring.js';
import aiRoutes from './routes/ai.js';
import practiceRoutes from './routes/practice.js';
import codingPracticeRoutes from './routes/codingPractice.js';
import cpCodeRoutes from './routes/cpCode.js';
import cpAnalysisRoutes from './routes/cpAnalysis.js';
import cpReportsRoutes from './routes/cpReports.js';
import cpSessionRoutes from './routes/cpSession.js';
import cpQuestionsRoutes from './routes/cpQuestions.js';
import cpAiQuestionsRoutes from './routes/cpAiQuestions.js';
import aiInterviewRoutes from './routes/aiInterview.js';
import axiomChatRoutes from './routes/axiomChat.js';
import {setupSocketHandlers} from './socket/handlers.js';

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

// Initialize Database
await initializeDatabase();

// Routes
app.use('/api/interview', interviewRoutes);
app.use('/api/questions', questionRoutes);
app.use('/api/code-execution', codeExecutionRoutes);
app.use('/api/proctoring', proctoringRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/practice', practiceRoutes);
app.use('/api/coding-practice', codingPracticeRoutes);
app.use('/api/cp/code', cpCodeRoutes);
app.use('/api/cp/analysis', cpAnalysisRoutes);
app.use('/api/cp/reports', cpReportsRoutes);
app.use('/api/cp/session', cpSessionRoutes);
app.use('/api/cp/questions', cpQuestionsRoutes);
app.use('/api/cp/ai-questions', cpAiQuestionsRoutes);
app.use('/api/ai-interview', aiInterviewRoutes);
app.use('/api/axiom', axiomChatRoutes);

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

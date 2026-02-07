import {BrowserRouter as Router, Routes, Route} from 'react-router-dom'
import Navbar from './components/Navbar'
import Home from './pages/Home'
import Login from './pages/Login'
import Register from './pages/Register'
import ForgotPassword from './pages/ForgotPassword'
import InterviewRoom from './pages/InterviewRoom'
import PracticeMode from './pages/PracticeMode'
import SecondaryCameraView from './pages/SecondaryCameraView'
import ProctorDashboard from './pages/ProctorDashboard'
import PracticeSessionSetup from './pages/PracticeSessionSetup'
import PracticeInterviewRoom from './pages/PracticeInterviewRoom'
import PracticeFeedback from './pages/PracticeFeedback'
import AxiomChat from './pages/AxiomChat'
import AIInterviewSetup from './pages/AIInterviewSetup'
import AIInterviewRoom from './pages/AIInterviewRoom'
import AIInterviewReport from './pages/AIInterviewReport'
import RecruiterDashboard from './pages/RecruiterDashboard'
import CodingPractice from './pages/CodingPractice'
import './App.css'

function App()
{
    return (
        <Router>
            <div className="App">
                <Navbar />
                <Routes>
                    <Route path="/" element={<Home />} />
                    <Route path="/login" element={<Login />} />
                    <Route path="/register" element={<Register />} />
                    <Route path="/forgot-password" element={<ForgotPassword />} />
                    <Route path="/interview/:interviewId" element={<InterviewRoom />} />
                    <Route path="/practice" element={<PracticeMode />} />
                    <Route path="/practice-setup" element={<PracticeSessionSetup />} />
                    <Route path="/practice-interview/:sessionId" element={<PracticeInterviewRoom />} />
                    <Route path="/practice-feedback/:sessionId" element={<PracticeFeedback />} />
                    <Route path="/secondary-camera" element={<SecondaryCameraView />} />
                    <Route path="/proctor-dashboard" element={<ProctorDashboard />} />
                    <Route path="/axiom-chat" element={<AxiomChat />} />
                    <Route path="/ai-interview-setup" element={<AIInterviewSetup />} />
                    <Route path="/ai-interview/:sessionId" element={<AIInterviewRoom />} />
                    <Route path="/ai-interview-report/:sessionId" element={<AIInterviewReport />} />
                    <Route path="/recruiter-dashboard" element={<RecruiterDashboard />} />
                    <Route path="/coding-practice" element={<CodingPractice />} />
                </Routes>
            </div>
        </Router>
    )
}

export default App

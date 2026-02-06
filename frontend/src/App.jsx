import {BrowserRouter as Router, Routes, Route} from 'react-router-dom'
import Home from './pages/Home'
import InterviewRoom from './pages/InterviewRoom'
import PracticeMode from './pages/PracticeMode'
import SecondaryCameraView from './pages/SecondaryCameraView'
import ProctorDashboard from './pages/ProctorDashboard'
import PracticeSessionSetup from './pages/PracticeSessionSetup'
import PracticeInterviewRoom from './pages/PracticeInterviewRoom'
import PracticeFeedback from './pages/PracticeFeedback'
import './App.css'

function App()
{
    return (
        <Router>
            <div className="App">
                <Routes>
                    <Route path="/" element={<Home />} />
                    <Route path="/interview/:interviewId" element={<InterviewRoom />} />
                    <Route path="/practice" element={<PracticeMode />} />
                    <Route path="/practice-setup" element={<PracticeSessionSetup />} />
                    <Route path="/practice-interview/:sessionId" element={<PracticeInterviewRoom />} />
                    <Route path="/practice-feedback/:sessionId" element={<PracticeFeedback />} />
                    <Route path="/secondary-camera" element={<SecondaryCameraView />} />
                    <Route path="/proctor-dashboard" element={<ProctorDashboard />} />
                </Routes>
            </div>
        </Router>
    )
}

export default App

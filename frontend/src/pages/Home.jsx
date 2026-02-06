import {useState} from 'react';
import {useNavigate} from 'react-router-dom';
import {createInterview} from '../services/api';
import './Home.css';

function Home()
{
    const navigate=useNavigate();
    const [mode, setMode]=useState('recruiter');
    const [candidateName, setCandidateName]=useState('');
    const [recruiterName, setRecruiterName]=useState('');
    const [loading, setLoading]=useState(false);

    const handleStartInterview=async () =>
    {
        if (!candidateName||(mode==='recruiter'&&!recruiterName))
        {
            alert('Please fill in all fields');
            return;
        }

        setLoading(true);
        try
        {
            const response=await createInterview({
                mode,
                candidateName,
                recruiterName: mode==='recruiter'? recruiterName:'AI Interviewer',
            });

            const interviewId=response.data.id;
            navigate(`/interview/${interviewId}?mode=${mode}&name=${candidateName}&role=candidate`);
        } catch (error)
        {
            console.error('Error creating interview:', error);
            alert('Failed to create interview');
        } finally
        {
            setLoading(false);
        }
    };

    const handlePracticeMode=() =>
    {
        navigate('/practice-setup');
    };

    return (
        <div className="home">
            {/* Navbar */}
            <nav className="navbar">
                <div className="navbar-content">
                    <a href="/" className="logo">🎯 AI Interview Platform</a>
                    <div className="nav-links">
                        <a href="/" className="nav-link">Home</a>
                        <a href="/practice-setup" className="nav-link">Practice Interview</a>
                        <a href="/proctor-dashboard" className="nav-link proctor-link">🎯 Proctor Dashboard</a>
                    </div>
                </div>
            </nav>

            {/* Hero Section */}
            <div className="hero">
                <div className="container">
                    <h1 className="hero-title">AI-Powered Interview Platform</h1>
                    <p className="hero-subtitle">
                        Conduct live interviews with advanced proctoring or practice with AI
                    </p>

                    {/* Mode Cards */}
                    <div className="mode-cards">
                        {/* Recruiter Mode */}
                        <div className={`mode-card ${mode==='recruiter'? 'active':''}`}
                            onClick={() => setMode('recruiter')}>
                            <div className="mode-icon">👔</div>
                            <h3>Recruiter Interview Mode</h3>
                            <p>Live video interview with anti-cheating detection</p>
                            <ul className="feature-list">
                                <li>✓ Real-time video calling</li>
                                <li>✓ Collaborative code editor</li>
                                <li>✓ AI-powered proctoring</li>
                                <li>✓ Automated reports</li>
                            </ul>
                        </div>

                        {/* Practice Mode */}
                        <div className={`mode-card ${mode==='practice'? 'active':''}`}
                            onClick={() => setMode('practice')}>
                            <div className="mode-icon">💪</div>
                            <h3>Preparation Interview Mode</h3>
                            <p>Practice with AI interviewer and instant feedback</p>
                            <ul className="feature-list">
                                <li>✓ AI interviewer</li>
                                <li>✓ Instant feedback</li>
                                <li>✓ Progress tracking</li>
                                <li>✓ Unlimited attempts</li>
                            </ul>
                        </div>
                    </div>

                    {/* Interview Setup Form */}
                    <div className="setup-form card">
                        <h2>{mode==='recruiter'? 'Start  Live Interview':'Start Practice Session'}</h2>

                        <div className="form-group">
                            <label className="label">Candidate Name</label>
                            <input
                                type="text"
                                className="input"
                                placeholder="Enter your name"
                                value={candidateName}
                                onChange={(e) => setCandidateName(e.target.value)}
                            />
                        </div>

                        {mode==='recruiter'&&(
                            <div className="form-group">
                                <label className="label">Recruiter Name</label>
                                <input
                                    type="text"
                                    className="input"
                                    placeholder="Enter recruiter name"
                                    value={recruiterName}
                                    onChange={(e) => setRecruiterName(e.target.value)}
                                />
                            </div>
                        )}

                        <button
                            className="btn btn-primary btn-large"
                            onClick={mode==='recruiter'? handleStartInterview:handlePracticeMode}
                            disabled={loading}
                        >
                            {loading? 'Creating...':mode==='recruiter'? '🚀 Start Interview':'💪 Start Practice'}
                        </button>
                    </div>

                    {/* Features Section */}
                    <div className="features-grid">
                        <div className="feature-card card">
                            <div className="feature-icon">🎥</div>
                            <h3>Video Conferencing</h3>
                            <p>HD video & audio with WebRTC technology</p>
                        </div>

                        <div className="feature-card card">
                            <div className="feature-icon">💻</div>
                            <h3>Live Code Editor</h3>
                            <p>Collaborative coding with syntax highlighting</p>
                        </div>

                        <div className="feature-card card">
                            <div className="feature-icon">🛡️</div>
                            <h3>AI Proctoring</h3>
                            <p>Advanced cheating detection with face tracking</p>
                        </div>

                        <div className="feature-card card">
                            <div className="feature-icon">🤖</div>
                            <h3>AI Assistant</h3>
                            <p>Automated feedback and code evaluation</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}

export default Home;

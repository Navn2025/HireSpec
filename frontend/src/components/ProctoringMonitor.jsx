import {useState, useEffect} from 'react';
import './ProctoringMonitor.css';

function ProctoringMonitor({interviewId, events, suspicionScore=0, integrityScore: propIntegrityScore})
{
    const [integrityScore, setIntegrityScore]=useState(100);
    const [alertCount, setAlertCount]=useState(0);
    const [criticalAlerts, setCriticalAlerts]=useState(0);
    const [newEventPulse, setNewEventPulse]=useState(false);

    useEffect(() =>
    {
        // Use prop if provided, otherwise calculate from events
        if (propIntegrityScore!==undefined)
        {
            setIntegrityScore(propIntegrityScore);
        } else
        {
            // Calculate score based on events
            let score=100;
            events.forEach(event =>
            {
                switch (event.severity)
                {
                    case 'low':
                        score-=5;
                        break;
                    case 'medium':
                        score-=10;
                        break;
                    case 'high':
                        score-=20;
                        break;
                    case 'critical':
                        score-=30;
                        break;
                }
            });
            setIntegrityScore(Math.max(0, score));
        }

        setAlertCount(events.length);
        setCriticalAlerts(events.filter(e => e.severity==='critical').length);

        // Trigger pulse animation for new events
        if (events.length>0)
        {
            setNewEventPulse(true);
            const timer=setTimeout(() => setNewEventPulse(false), 1000);
            return () => clearTimeout(timer);
        }
    }, [events, propIntegrityScore]);

    const getScoreColor=() =>
    {
        if (integrityScore>=80) return '#10b981';
        if (integrityScore>=60) return '#f59e0b';
        return '#ef4444';
    };

    const getSeverityBadge=(severity) =>
    {
        const colors={
            low: '#60a5fa',
            medium: '#f59e0b',
            high: '#ef4444',
            critical: '#dc2626',
        };
        return colors[severity]||'#64748b';
    };

    const formatEventType=(event) =>
    {
        const typeMap={
            'no_face': '😶 No Face Detected',
            'multiple_faces': '👥 Multiple Faces',
            'looking_away': '👁️ Looking Away',
            'eyes_closed': '😴 Eyes Closed',
            'window_blur': '🪟 Window Focus Lost',
            'tab_switch': '🔄 Tab Switched',
            'fullscreen_exit': '📺 Fullscreen Exited',
            'copy_paste_attempt': '📋 Copy/Paste Blocked',
            'ai_generated_code': '🤖 AI-Generated Code',
            'large_paste': '📄 Large Code Paste',
            'suspicious_typing': '⌨️ Suspicious Typing',
            'auto_terminate': '⛔ Interview Terminated',
        };
        return typeMap[event.type]||event.description||event.type||'Unknown Event';
    };

    return (
        <div className="proctoring-monitor card">
            <div className="proctoring-header">
                <h3>🛡️ Proctoring Monitor</h3>
            </div>

            <div className="integrity-score">
                <div className="score-label">Integrity Score</div>
                <div className="score-value" style={{color: getScoreColor()}}>
                    {integrityScore}/100
                </div>
                <div className="score-bar">
                    <div
                        className="score-fill"
                        style={{
                            width: `${integrityScore}%`,
                            background: getScoreColor()
                        }}
                    />
                </div>
            </div>

            <div className="proctoring-stats">
                <div className="stat">
                    <div className="stat-label">Total Alerts</div>
                    <div className="stat-value">{alertCount}</div>
                </div>
                <div className="stat">
                    <div className="stat-label">Critical</div>
                    <div className="stat-value" style={{color: criticalAlerts>0? '#ef4444':'#10b981'}}>
                        {criticalAlerts}
                    </div>
                </div>
                <div className="stat">
                    <div className="stat-label">Status</div>
                    <div className="stat-value status">
                        {integrityScore>=80? '✅ Good':integrityScore>=60? '⚠️ Warning':'❌ Risk'}
                    </div>
                </div>
            </div>

            <div className="monitoring-features">
                <div className="features-label">Active Monitoring</div>
                <div className="feature-badges">
                    <span className="feature-badge" title="Face detection and tracking">👤 Face</span>
                    <span className="feature-badge" title="Eye tracking and gaze detection">👁️ Eyes</span>
                    <span className="feature-badge" title="AI-generated code detection">🤖 AI</span>
                    <span className="feature-badge" title="Tab and window monitoring">🪟 Focus</span>
                    <span className="feature-badge" title="Secondary camera (phone)">📱 Camera 2</span>
                </div>
            </div>

            <div className="events-list">
                <div className="events-header">
                    Recent Events
                    {newEventPulse&&<span className="live-indicator">🔴 LIVE</span>}
                </div>

                {events.length===0? (
                    <div className="no-events">
                        <span>✓</span>
                        <p>No violations detected</p>
                    </div>
                ):(
                    <div className="events">
                        {events.slice(-10).reverse().map((event, index) => (
                            <div key={index} className="event-item">
                                <div
                                    className="event-severity"
                                    style={{background: getSeverityBadge(event.severity)}}
                                />
                                <div className="event-content">
                                    <div className="event-type">{formatEventType(event)}</div>
                                    <div className="event-time">
                                        {new Date(event.timestamp).toLocaleTimeString()}
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}

export default ProctoringMonitor;

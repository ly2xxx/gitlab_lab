// GitLab Workflows Lab - Frontend Application JavaScript

class GitLabWorkflowsApp {
    constructor() {
        this.apiBaseUrl = this.detectApiUrl();
        this.pipelineData = {
            id: this.generateMockPipelineId(),
            status: 'success',
            environment: 'development',
            version: '1.0.0',
            lastDeployment: new Date().toISOString()
        };
        
        this.init();
    }

    init() {
        this.updatePipelineStatus();
        this.setupEventListeners();
        this.startPeriodicUpdates();
        console.log('🚀 GitLab Workflows Lab App initialized');
    }

    detectApiUrl() {
        // Detect if running in different environments
        const hostname = window.location.hostname;
        if (hostname === 'localhost' || hostname === '127.0.0.1') {
            return 'http://localhost:5000/api';
        } else if (hostname.includes('staging')) {
            return '/api'; // Staging environment
        } else if (hostname.includes('production')) {
            return '/api'; // Production environment
        }
        return '/api'; // Default
    }

    generateMockPipelineId() {
        return Math.floor(Math.random() * 10000) + 1000;
    }

    updatePipelineStatus() {
        // Update pipeline status in the UI
        const elements = {
            environment: document.getElementById('environment'),
            version: document.getElementById('version'),
            buildStatus: document.getElementById('build-status'),
            deploymentTime: document.getElementById('deployment-time')
        };

        if (elements.environment) {
            elements.environment.textContent = this.pipelineData.environment;
        }
        
        if (elements.version) {
            elements.version.textContent = this.pipelineData.version;
        }
        
        if (elements.buildStatus) {
            elements.buildStatus.textContent = `✅ ${this.pipelineData.status}`;
            elements.buildStatus.className = `value ${this.pipelineData.status}`;
        }
        
        if (elements.deploymentTime) {
            const deployTime = new Date(this.pipelineData.lastDeployment);
            elements.deploymentTime.textContent = deployTime.toLocaleString();
        }
    }

    setupEventListeners() {
        // Add click event listeners for buttons
        document.addEventListener('DOMContentLoaded', () => {
            console.log('DOM loaded, setting up event listeners');
        });

        // Handle window resize for responsive behavior
        window.addEventListener('resize', this.handleResize.bind(this));
    }

    handleResize() {
        // Handle responsive layout changes
        console.log('Window resized:', window.innerWidth, 'x', window.innerHeight);
    }

    startPeriodicUpdates() {
        // Simulate periodic updates to pipeline data
        setInterval(() => {
            this.simulateDataUpdate();
        }, 30000); // Update every 30 seconds
    }

    simulateDataUpdate() {
        // Simulate random pipeline data updates
        const statuses = ['success', 'running', 'pending'];
        const environments = ['development', 'staging', 'production'];
        
        this.pipelineData.status = statuses[Math.floor(Math.random() * statuses.length)];
        
        if (Math.random() > 0.8) {
            this.pipelineData.environment = environments[Math.floor(Math.random() * environments.length)];
            this.pipelineData.lastDeployment = new Date().toISOString();
        }
        
        this.updatePipelineStatus();
    }
}

// Workflow simulation functions
function simulateBuild() {
    const output = document.getElementById('test-output');
    if (!output) return;
    
    output.innerHTML = '';
    output.classList.add('fade-in');
    
    const steps = [
        '🔧 Initializing build environment...',
        '📦 Installing dependencies...',
        '🔨 Compiling source code...',
        '🧪 Running unit tests...',
        '📋 Generating build artifacts...',
        '✅ Build completed successfully!'
    ];
    
    let stepIndex = 0;
    const interval = setInterval(() => {
        if (stepIndex < steps.length) {
            output.innerHTML += steps[stepIndex] + '\n';
            output.scrollTop = output.scrollHeight;
            stepIndex++;
        } else {
            clearInterval(interval);
            output.innerHTML += '\n🎉 Build process finished!\n';
        }
    }, 800);
}

function simulateTest() {
    const output = document.getElementById('test-output');
    if (!output) return;
    
    output.innerHTML = '';
    output.classList.add('fade-in');
    
    const tests = [
        { name: 'Frontend Unit Tests', duration: 1200, status: 'pass' },
        { name: 'Backend API Tests', duration: 1500, status: 'pass' },
        { name: 'Integration Tests', duration: 2000, status: 'pass' },
        { name: 'Security Scans', duration: 1800, status: 'pass' },
        { name: 'Performance Tests', duration: 2500, status: 'pass' }
    ];
    
    output.innerHTML = '🧪 Starting test suite...\n\n';
    
    let testIndex = 0;
    function runNextTest() {
        if (testIndex < tests.length) {
            const test = tests[testIndex];
            output.innerHTML += `▶️ Running ${test.name}...\n`;
            output.scrollTop = output.scrollHeight;
            
            setTimeout(() => {
                const statusIcon = test.status === 'pass' ? '✅' : '❌';
                output.innerHTML += `${statusIcon} ${test.name} ${test.status.toUpperCase()}\n`;
                output.scrollTop = output.scrollHeight;
                testIndex++;
                runNextTest();
            }, test.duration);
        } else {
            output.innerHTML += '\n🎉 All tests completed successfully!\n';
            output.innerHTML += '📊 Test Summary: 5 passed, 0 failed\n';
        }
    }
    
    runNextTest();
}

function simulateDeploy() {
    const output = document.getElementById('test-output');
    if (!output) return;
    
    output.innerHTML = '';
    output.classList.add('fade-in');
    
    const deploySteps = [
        '🚀 Preparing deployment...',
        '🔍 Validating deployment configuration...',
        '📦 Building deployment artifacts...',
        '🌐 Updating load balancer configuration...',
        '🐳 Deploying containers...',
        '🔄 Running database migrations...',
        '🩺 Performing health checks...',
        '📊 Updating monitoring dashboards...',
        '✅ Deployment completed successfully!'
    ];
    
    let stepIndex = 0;
    const interval = setInterval(() => {
        if (stepIndex < deploySteps.length) {
            output.innerHTML += deploySteps[stepIndex] + '\n';
            output.scrollTop = output.scrollHeight;
            stepIndex++;
        } else {
            clearInterval(interval);
            output.innerHTML += '\n🌍 Application deployed to: https://staging.example.com\n';
            output.innerHTML += '📈 Deployment metrics available in monitoring dashboard\n';
        }
    }, 1000);
}

function showPipelineInfo() {
    const output = document.getElementById('test-output');
    if (!output) return;
    
    const app = window.gitlabApp || {};
    const pipelineData = app.pipelineData || {};
    
    output.innerHTML = '';
    output.classList.add('fade-in');
    
    const info = `📊 Pipeline Information
=======================

Pipeline ID: ${pipelineData.id || 'N/A'}
Status: ${pipelineData.status || 'unknown'}
Environment: ${pipelineData.environment || 'development'}
Version: ${pipelineData.version || '1.0.0'}
Last Deployment: ${pipelineData.lastDeployment ? new Date(pipelineData.lastDeployment).toLocaleString() : 'N/A'}

🔧 Workflow Features Active:
- ✅ Basic Pipeline Triggers
- ✅ Parent-Child Pipelines  
- ✅ Multi-Project Pipelines
- ✅ Scheduled Pipelines
- ✅ Advanced Workflow Patterns

🌐 Environment URLs:
- Development: http://localhost:3000
- Staging: https://staging.example.com
- Production: https://production.example.com

📚 Documentation: Available in README.md
🛠️ Source Code: Check .gitlab-ci.yml for pipeline configuration
`;
    
    output.innerHTML = info;
}

async function checkAPI() {
    const responseDiv = document.getElementById('api-response');
    if (!responseDiv) return;
    
    responseDiv.innerHTML = '🔄 Checking API health...';
    responseDiv.classList.add('loading');
    
    try {
        // Simulate API health check
        await new Promise(resolve => setTimeout(resolve, 1500));
        
        const healthData = {
            status: 'healthy',
            version: '2.0.0',
            uptime: '3d 12h 45m',
            database: 'connected',
            cache: 'operational',
            external_services: 'available',
            last_check: new Date().toISOString()
        };
        
        responseDiv.classList.remove('loading');
        responseDiv.innerHTML = `📊 API Health Check Results
============================

Status: ✅ ${healthData.status.toUpperCase()}
Version: ${healthData.version}
Uptime: ${healthData.uptime}
Database: ✅ ${healthData.database}
Cache: ✅ ${healthData.cache}
External Services: ✅ ${healthData.external_services}
Last Check: ${new Date(healthData.last_check).toLocaleString()}

🔗 Endpoints:
- GET /health - Health check
- GET /metrics - Application metrics  
- POST /webhook - GitLab webhook receiver
- GET /pipeline/{id} - Pipeline status

🚀 API is ready for GitLab CI/CD integration!`;
        
    } catch (error) {
        responseDiv.classList.remove('loading');
        responseDiv.innerHTML = `❌ API Health Check Failed
============================

Error: ${error.message}
Timestamp: ${new Date().toLocaleString()}

🔧 Troubleshooting:
1. Check if backend service is running
2. Verify network connectivity
3. Review application logs
4. Restart services if necessary`;
    }
}

function showLabInfo() {
    alert(`GitLab Workflows Lab - Information

This lab demonstrates comprehensive GitLab CI/CD workflow patterns:

🎯 Learning Objectives:
• Master different pipeline trigger types
• Understand parent-child pipeline relationships  
• Implement multi-project dependencies
• Configure scheduled pipeline automation
• Apply advanced workflow patterns

📚 Resources:
• README.md - Complete lab documentation
• .gitlab-ci.yml - Main pipeline configuration
• .gitlab/ci/ - Modular CI configurations
• scripts/ - Helper scripts and utilities

🚀 Get Started:
1. Follow setup instructions in README.md
2. Make changes to trigger different workflows
3. Observe pipeline behavior in GitLab UI
4. Experiment with different configurations

Happy learning! 🎓`);
}

// Utility functions
function formatTimestamp(timestamp) {
    return new Date(timestamp).toLocaleString();
}

function showNotification(message, type = 'info') {
    // Simple notification system
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 12px 24px;
        border-radius: 6px;
        color: white;
        font-weight: 500;
        z-index: 1000;
        animation: slideIn 0.3s ease-out;
    `;
    
    const colors = {
        info: '#2563eb',
        success: '#059669',
        warning: '#d97706',
        error: '#dc2626'
    };
    
    notification.style.backgroundColor = colors[type] || colors.info;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease-in';
        setTimeout(() => {
            document.body.removeChild(notification);
        }, 300);
    }, 3000);
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.gitlabApp = new GitLabWorkflowsApp();
    console.log('🎉 GitLab Workflows Lab application ready!');
});

// Add CSS animations for notifications
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    
    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);
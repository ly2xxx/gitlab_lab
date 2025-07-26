#!/usr/bin/env python3
# scripts/generate-compliance-report.py

import json
import os
from datetime import datetime
from pathlib import Path

def load_security_reports():
    """Load all security scan reports"""
    reports = {}
    
    # Load SAST reports
    sast_files = ['gl-sast-report.json', 'eslint-security.json']
    for file in sast_files:
        if os.path.exists(file):
            with open(file, 'r') as f:
                reports[f'sast_{file}'] = json.load(f)
    
    # Load dependency scanning reports
    dep_files = ['npm-audit.json', 'snyk-test.json']
    for file in dep_files:
        if os.path.exists(file):
            with open(file, 'r') as f:
                reports[f'dependency_{file}'] = json.load(f)
    
    # Load container scanning reports
    container_files = ['trivy-container.json', 'grype-container.json']
    for file in container_files:
        if os.path.exists(file):
            with open(file, 'r') as f:
                reports[f'container_{file}'] = json.load(f)
    
    return reports

def analyze_vulnerabilities(reports):
    """Analyze vulnerabilities from all reports"""
    vulnerability_summary = {
        'critical': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
        'total': 0
    }
    
    detailed_vulnerabilities = []
    
    for report_name, report_data in reports.items():
        if 'vulnerabilities' in report_data:
            vulns = report_data['vulnerabilities']
            for vuln in vulns:
                severity = vuln.get('severity', 'unknown').lower()
                if severity in vulnerability_summary:
                    vulnerability_summary[severity] += 1
                vulnerability_summary['total'] += 1
                
                detailed_vulnerabilities.append({
                    'source': report_name,
                    'id': vuln.get('id', 'unknown'),
                    'title': vuln.get('title', vuln.get('message', 'Unknown')),
                    'severity': severity,
                    'location': vuln.get('location', {}),
                    'description': vuln.get('description', '')
                })
    
    return vulnerability_summary, detailed_vulnerabilities

def generate_compliance_score(vulnerability_summary):
    """Calculate compliance score based on vulnerabilities"""
    total_vulns = vulnerability_summary['total']
    critical_vulns = vulnerability_summary['critical']
    high_vulns = vulnerability_summary['high']
    
    # Base score starts at 100
    score = 100
    
    # Deduct points for vulnerabilities
    score -= critical_vulns * 20  # -20 points per critical
    score -= high_vulns * 10      # -10 points per high
    score -= vulnerability_summary['medium'] * 2  # -2 points per medium
    score -= vulnerability_summary['low'] * 1     # -1 point per low
    
    # Ensure score doesn't go below 0
    score = max(0, score)
    
    # Determine compliance level
    if score >= 90:
        level = 'EXCELLENT'
    elif score >= 75:
        level = 'GOOD'
    elif score >= 60:
        level = 'ACCEPTABLE'
    elif score >= 40:
        level = 'NEEDS_IMPROVEMENT'
    else:
        level = 'CRITICAL'
    
    return score, level

def generate_html_report(compliance_data):
    """Generate HTML compliance report"""
    html_template = """
<!DOCTYPE html>
<html>
<head>
    <title>Security Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
        .score { font-size: 2em; font-weight: bold; }
        .excellent { color: #4CAF50; }
        .good { color: #8BC34A; }
        .acceptable { color: #FF9800; }
        .needs_improvement { color: #FF5722; }
        .critical { color: #F44336; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .metric { background: #f9f9f9; padding: 15px; border-radius: 5px; flex: 1; }
        .vulnerabilities { margin-top: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Security Compliance Report</h1>
        <p>Generated: {timestamp}</p>
        <p>Commit: {commit_sha}</p>
        <div class="score {level_class}">Compliance Score: {score}/100 ({level})</div>
    </div>
    
    <div class="summary">
        <div class="metric">
            <h3>Critical Vulnerabilities</h3>
            <div style="font-size: 2em; color: #F44336;">{critical}</div>
        </div>
        <div class="metric">
            <h3>High Vulnerabilities</h3>
            <div style="font-size: 2em; color: #FF5722;">{high}</div>
        </div>
        <div class="metric">
            <h3>Medium Vulnerabilities</h3>
            <div style="font-size: 2em; color: #FF9800;">{medium}</div>
        </div>
        <div class="metric">
            <h3>Total Vulnerabilities</h3>
            <div style="font-size: 2em;">{total}</div>
        </div>
    </div>
    
    <div class="vulnerabilities">
        <h2>Detailed Vulnerabilities</h2>
        <table>
            <tr>
                <th>Source</th>
                <th>ID</th>
                <th>Title</th>
                <th>Severity</th>
            </tr>
            {vulnerability_rows}
        </table>
    </div>
</body>
</html>
    """
    
    # Generate vulnerability rows
    vulnerability_rows = ""
    for vuln in compliance_data['detailed_vulnerabilities'][:50]:  # Limit to first 50
        vulnerability_rows += f"""
            <tr>
                <td>{vuln['source']}</td>
                <td>{vuln['id']}</td>
                <td>{vuln['title']}</td>
                <td>{vuln['severity']}</td>
            </tr>
        """
    
    html_content = html_template.format(
        timestamp=compliance_data['timestamp'],
        commit_sha=compliance_data.get('commit_sha', 'unknown'),
        score=compliance_data['compliance_score'],
        level=compliance_data['compliance_level'],
        level_class=compliance_data['compliance_level'].lower(),
        critical=compliance_data['vulnerability_summary']['critical'],
        high=compliance_data['vulnerability_summary']['high'],
        medium=compliance_data['vulnerability_summary']['medium'],
        total=compliance_data['vulnerability_summary']['total'],
        vulnerability_rows=vulnerability_rows
    )
    
    with open('compliance-report.html', 'w') as f:
        f.write(html_content)

def main():
    """Main function to generate compliance report"""
    print("Generating security compliance report...")
    
    # Load all security reports
    reports = load_security_reports()
    
    if not reports:
        print("No security reports found. Skipping compliance report generation.")
        return
    
    # Analyze vulnerabilities
    vulnerability_summary, detailed_vulnerabilities = analyze_vulnerabilities(reports)
    
    # Calculate compliance score
    compliance_score, compliance_level = generate_compliance_score(vulnerability_summary)
    
    # Prepare compliance data
    compliance_data = {
        'timestamp': datetime.now().isoformat(),
        'commit_sha': os.environ.get('CI_COMMIT_SHA', 'unknown'),
        'pipeline_id': os.environ.get('CI_PIPELINE_ID', 'unknown'),
        'vulnerability_summary': vulnerability_summary,
        'detailed_vulnerabilities': detailed_vulnerabilities,
        'compliance_score': compliance_score,
        'compliance_level': compliance_level,
        'reports_analyzed': list(reports.keys())
    }
    
    # Save JSON report
    with open('compliance-report.json', 'w') as f:
        json.dump(compliance_data, f, indent=2)
    
    # Generate HTML report
    generate_html_report(compliance_data)
    
    print(f"Compliance report generated:")
    print(f"  Score: {compliance_score}/100 ({compliance_level})")
    print(f"  Total vulnerabilities: {vulnerability_summary['total']}")
    print(f"  Critical: {vulnerability_summary['critical']}")
    print(f"  High: {vulnerability_summary['high']}")
    print(f"  Reports: compliance-report.json, compliance-report.html")

if __name__ == '__main__':
    main()

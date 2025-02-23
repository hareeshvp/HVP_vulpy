# Synopsys Coverity and Black Duck on a Windows self-hosted runner running from cmd propt
name: Synopsys AppSec

on:
  push:
    branches: [ "master" ]
  pull_request:
    branches: [ "master" ]
    
  # Allows you to run this workflow manually from the Actions tab
  workflow_dispatch:

jobs:
  appsec:
    runs-on: self-hosted
    
    env:
      COV_URL: ${{ secrets.COVERITY_URL }}
      COV_USER: ${{ secrets.COVERITY_USER }}
      COVERITY_PASSPHRASE: ${{ secrets.COVERITY_PASSPHRASE }}
      PROJECT_NAME: ${GITHUB_REPOSITORY#*/}
      VERSION_NAME: ${GITHUB_REF_NAME#*/}
      
    steps:
      - uses: actions/checkout@v3

      - name: Set up JDK 11
        uses: actions/setup-java@v2
        with:
          java-version: '11'
          distribution: 'adopt'

      - name: Setup Python
        uses: actions/setup-python@v3
        with:
          python-version: '3.x'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          
      - name: Coverity SAST Scan
        run: |
          cov-capture --dir idir --project-dir .
          cov-analyze --dir idir --ticker-mode none --webapp-security --all
          cov-commit-defects --dir idir --ticker-mode none --url ${{ secrets.COVERITY_URL }} --on-new-cert trust --stream HVP_vulpy
          
      - name: Coverity Security Gate
        run: |
          curl.exe -u ${{ secrets.COVERITY_USER }}:${{ secrets.COVERITY_PASSPHRASE }} -o security-gate-results.json ${{ secrets.COVERITY_URL }}/api/viewContents/issues/v1/High%20Impact%20Outstanding?projectId=HVP_vulpy
          if ($(type security-gate-results.json | jq .viewContentsV1.totalRows) -ne 0 )
          {
            echo Security gate found policy violations
            ## type security-gate-results.json | jq .viewContentsV1.rows
            ## You may mark the build as failure
            ##exit 1;
          }
          else
          {
            echo No High Impact issues policy violations found
          }

      - name: Black Duck SCA Scan
        uses: synopsys-sig/detect-action@main
        env:
          DETECT_POLICY_CHECK_FAIL_ON_SEVERITIES: BLOCKER,CRITICAL 
        with:
          scan-mode: INTELLIGENT
          github-token: ${{ secrets.GITHUB_TOKEN }}
          detect-version: 7.12.0
          blackduck-url: ${{ secrets.BLACKDUCK_URL }}
          blackduck-api-token: ${{ secrets.BLACKDUCK_API_TOKEN }}

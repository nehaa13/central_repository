#!/bin/bash
# One-time script to generate SCXML workflow with dynamic dropdowns from JSON
# Run this once: chmod +x generate-scxml-workflow.sh && ./generate-scxml-workflow.sh

set -e

# Configuration
CONFIG_FILE="central_repository/scxml.json"
OUTPUT_FILE=".github/workflows/scxml-deployment.yml"

echo "🔧 Generating SCXML Deployment Workflow..."
echo "Source: ${CONFIG_FILE}"
echo "Output: ${OUTPUT_FILE}"

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: ${CONFIG_FILE} not found!"
    echo "Please ensure your scxml.json is at: ${CONFIG_FILE}"
    exit 1
fi

# Validate JSON
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "❌ Error: ${CONFIG_FILE} is not valid JSON!"
    exit 1
fi

# Create workflows directory
mkdir -p .github/workflows

# Start building the workflow
cat > $OUTPUT_FILE <<'HEADER'
name: SCXML Release Workflow

on:
  workflow_dispatch:
    inputs:
      lob_key:
        description: 'Select LOB'
        required: true
        type: choice
        options:
HEADER

# Add LOB keys
echo "  📋 Adding LOB keys..."
jq -r '.SCXML_APP_LISTS | keys[]' "$CONFIG_FILE" | while read lob_key; do
    echo "          - ${lob_key}" >> $OUTPUT_FILE
done

# Add target_app section
cat >> $OUTPUT_FILE <<'MIDDLE'
      target_app:
        description: 'Select Target Application (must match LOB above)'
        required: true
        type: choice
        options:
MIDDLE

# Add target apps
echo "  📦 Adding Target Applications..."
jq -r '.SCXML_TARGET_APP_LISTS | to_entries[] | .value[]' "$CONFIG_FILE" | sort -u | while read app; do
    echo "          - ${app}" >> $OUTPUT_FILE
done

# Add jobs section
cat >> $OUTPUT_FILE <<'JOBS'

env:
  CENTRAL_CONFIG_PATH: central_repository/scxml.json

jobs:
  validate-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Validate LOB and Target App Combination
        id: validate
        run: |
          LOB_KEY="${{ github.event.inputs.lob_key }}"
          TARGET_APP="${{ github.event.inputs.target_app }}"
          CONFIG_FILE="${{ env.CENTRAL_CONFIG_PATH }}"
          
          echo "🔍 Validating: ${LOB_KEY} -> ${TARGET_APP}"
          
          # Check if target app belongs to selected LOB
          IS_VALID=$(jq -r ".SCXML_TARGET_APP_LISTS.${LOB_KEY} | contains([\"${TARGET_APP}\"])" "$CONFIG_FILE")
          
          if [ "$IS_VALID" = "true" ]; then
            LOB_NAME=$(jq -r ".SCXML_APP_LISTS.${LOB_KEY}[0]" "$CONFIG_FILE")
            
            echo "✅ Valid combination: ${LOB_KEY} -> ${TARGET_APP}"
            echo "## ✅ Validation Passed" >> $GITHUB_STEP_SUMMARY
            echo "- **LOB Key**: ${LOB_KEY}" >> $GITHUB_STEP_SUMMARY
            echo "- **LOB Name**: ${LOB_NAME}" >> $GITHUB_STEP_SUMMARY
            echo "- **Target App**: ${TARGET_APP}" >> $GITHUB_STEP_SUMMARY
            
            echo "valid=true" >> $GITHUB_OUTPUT
            echo "lob_name=${LOB_NAME}" >> $GITHUB_OUTPUT
            echo "lob_key=${LOB_KEY}" >> $GITHUB_OUTPUT
          else
            echo "❌ Invalid combination!"
            echo "## ❌ Validation Failed" >> $GITHUB_STEP_SUMMARY
            echo "" >> $GITHUB_STEP_SUMMARY
            echo "**${TARGET_APP}** does not belong to **${LOB_KEY}**" >> $GITHUB_STEP_SUMMARY
            echo "" >> $GITHUB_STEP_SUMMARY
            echo "### ✅ Valid Target Applications for ${LOB_KEY}:" >> $GITHUB_STEP_SUMMARY
            jq -r ".SCXML_TARGET_APP_LISTS.${LOB_KEY}[]" "$CONFIG_FILE" | while read app; do
              echo "- \`${app}\`" >> $GITHUB_STEP_SUMMARY
            done
            exit 1
          fi

      - name: Extract Additional Configuration
        if: steps.validate.outputs.valid == 'true'
        id: config
        run: |
          LOB_KEY="${{ steps.validate.outputs.lob_key }}"
          CONFIG_FILE="${{ env.CENTRAL_CONFIG_PATH }}"
          
          # Extract email DL
          EMAIL_DL=$(jq -r ".SCXML_EMAIL_CONFIG.${LOB_KEY}_teamEmailDL[0] // \"\"" "$CONFIG_FILE")
          
          # Extract Git config
          GIT_REPO=$(jq -r '.SCXML_GIT_CONFIG.GIT_Repo[0] // ""' "$CONFIG_FILE")
          GIT_USER=$(jq -r '.SCXML_GIT_CONFIG.GIT_userName[0] // ""' "$CONFIG_FILE")
          
          # Extract JFrog config
          ARTIFACTORY_USER=$(jq -r '.SCXML_JFROG_CONFIG.SCXML_artifactoryUserID[0] // ""' "$CONFIG_FILE")
          ARTIFACTORY_BASE_URL=$(jq -r '.SCXML_JFROG_CONFIG.SCXML_searchArtifactoryBaseURL[0] // ""' "$CONFIG_FILE")
          
          echo "email_dl=${EMAIL_DL}" >> $GITHUB_OUTPUT
          echo "git_repo=${GIT_REPO}" >> $GITHUB_OUTPUT
          echo "git_user=${GIT_USER}" >> $GITHUB_OUTPUT
          echo "artifactory_user=${ARTIFACTORY_USER}" >> $GITHUB_OUTPUT
          echo "artifactory_url=${ARTIFACTORY_BASE_URL}" >> $GITHUB_OUTPUT
          
          echo "### 📋 Configuration Details" >> $GITHUB_STEP_SUMMARY
          echo "- **Email DL**: ${EMAIL_DL}" >> $GITHUB_STEP_SUMMARY
          echo "- **Git Repo**: ${GIT_REPO}" >> $GITHUB_STEP_SUMMARY
          echo "- **Git User**: ${GIT_USER}" >> $GITHUB_STEP_SUMMARY

      - name: Deploy SCXML Application
        if: steps.validate.outputs.valid == 'true'
        env:
          LOB_KEY: ${{ steps.validate.outputs.lob_key }}
          LOB_NAME: ${{ steps.validate.outputs.lob_name }}
          TARGET_APP: ${{ github.event.inputs.target_app }}
          EMAIL_DL: ${{ steps.config.outputs.email_dl }}
          GIT_REPO: ${{ steps.config.outputs.git_repo }}
          GIT_USER: ${{ steps.config.outputs.git_user }}
          ARTIFACTORY_USER: ${{ steps.config.outputs.artifactory_user }}
          ARTIFACTORY_URL: ${{ steps.config.outputs.artifactory_url }}
        run: |
          echo "🚀 Starting SCXML Deployment"
          echo "========================================"
          echo "LOB Key:           ${LOB_KEY}"
          echo "LOB Name:          ${LOB_NAME}"
          echo "Target App:        ${TARGET_APP}"
          echo "Email DL:          ${EMAIL_DL}"
          echo "Git Repository:    ${GIT_REPO}"
          echo "Git User:          ${GIT_USER}"
          echo "Artifactory User:  ${ARTIFACTORY_USER}"
          echo "Artifactory URL:   ${ARTIFACTORY_URL}"
          echo "========================================"
          
          # Your deployment commands here
          # Example:
          # ./scripts/deploy-scxml.sh \
          #   --lob="${LOB_NAME}" \
          #   --app="${TARGET_APP}" \
          #   --config="${{ env.CENTRAL_CONFIG_PATH }}"
          
          echo "✅ Deployment completed successfully"

      - name: Deployment Summary
        if: success()
        run: |
          echo "## 🎉 SCXML Deployment Successful" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Parameter | Value |" >> $GITHUB_STEP_SUMMARY
          echo "|-----------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| **LOB Key** | ${{ steps.validate.outputs.lob_key }} |" >> $GITHUB_STEP_SUMMARY
          echo "| **LOB Name** | ${{ steps.validate.outputs.lob_name }} |" >> $GITHUB_STEP_SUMMARY
          echo "| **Target Application** | ${{ github.event.inputs.target_app }} |" >> $GITHUB_STEP_SUMMARY
          echo "| **Deployed By** | ${{ github.actor }} |" >> $GITHUB_STEP_SUMMARY
          echo "| **Timestamp** | $(date -u '+%Y-%m-%d %H:%M:%S UTC') |" >> $GITHUB_STEP_SUMMARY

      - name: Notify on Failure
        if: failure()
        run: |
          echo "## ❌ Deployment Failed" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "Please check the logs above for details." >> $GITHUB_STEP_SUMMARY
          echo "**Contact**: ${{ steps.config.outputs.email_dl }}" >> $GITHUB_STEP_SUMMARY
JOBS

echo ""
echo "✅ Workflow generated successfully!"
echo "📄 File created: ${OUTPUT_FILE}"
echo ""
echo "📊 Summary:"
LOB_COUNT=$(jq -r '.SCXML_APP_LISTS | keys | length' "$CONFIG_FILE")
APP_COUNT=$(jq -r '.SCXML_TARGET_APP_LISTS | to_entries[] | .value[]' "$CONFIG_FILE" | wc -l)
echo "  - LOBs: ${LOB_COUNT}"
echo "  - Target Applications: ${APP_COUNT}"
echo ""
echo "🚀 Next steps:"
echo "  1. Review: cat ${OUTPUT_FILE}"
echo "  2. Commit: git add ${OUTPUT_FILE} central_repository/scxml.json"
echo "  3. Push:   git commit -m 'Add SCXML deployment workflow' && git push"
echo ""
echo "✨ Your workflow is ready to use!"

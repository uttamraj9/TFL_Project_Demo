#!/bin/bash
###############################################################################
# Update Jenkins Pipeline to Use Fixed Jenkinsfile
# Then trigger a test build
###############################################################################

set -e

JENKINS_URL="http://51.24.13.205:8081"
JENKINS_USER="consultant"
JENKINS_PASSWORD="WelcomeItc@2026"
JOB_NAME="TfL_Spark_Pipeline"

echo "============================================"
echo "Update Jenkins Pipeline to Fixed Version"
echo "============================================"
echo ""

# Step 1: Get Jenkins CRUMB
echo "Step 1: Authenticating with Jenkins..."
CRUMB=$(curl -s -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
  --cookie-jar /tmp/jenkins-cookie \
  "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")

if [ -z "$CRUMB" ]; then
    echo "ERROR: Failed to authenticate"
    exit 1
fi
echo "✓ Authenticated"
echo ""

# Step 2: Update job configuration to use new Jenkinsfile
echo "Step 2: Updating job configuration..."

cat > /tmp/pipeline_config_updated.xml << 'XML_EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>TfL PySpark Pipeline - Fixed Version with Resource Profiles</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.ChoiceParameterDefinition>
          <name>SPARK_SCRIPT</name>
          <description>Select which PySpark script to run</description>
          <choices class="java.util.Arrays$ArrayList">
            <a class="string-array">
              <string>simple_spark_wordcount.py</string>
              <string>tfl_spark_analysis.py</string>
            </a>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
        <hudson.model.ChoiceParameterDefinition>
          <name>RESOURCE_PROFILE</name>
          <description>Resource allocation profile (minimal=512M, standard=1G, large=2G)</description>
          <choices class="java.util.Arrays$ArrayList">
            <a class="string-array">
              <string>minimal</string>
              <string>standard</string>
              <string>large</string>
            </a>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition">
    <scm class="hudson.plugins.git.GitSCM">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/uttamraj9/TFL_Project_Demo.git</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>Jenkinsfile_Spark_Fixed</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
XML_EOF

# Update the job
curl -s -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -H "Content-Type: application/xml" \
  -X POST \
  --data-binary @/tmp/pipeline_config_updated.xml \
  "${JENKINS_URL}/job/${JOB_NAME}/config.xml"

if [ $? -eq 0 ]; then
    echo "✓ Job configuration updated"
else
    echo "✗ Failed to update job"
    exit 1
fi
echo ""

# Step 3: Trigger a test build
echo "Step 3: Triggering test build..."
echo "Settings:"
echo "  SPARK_SCRIPT: simple_spark_wordcount.py"
echo "  RESOURCE_PROFILE: minimal (512M memory)"
echo ""

curl -s -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -X POST \
  "${JENKINS_URL}/job/${JOB_NAME}/buildWithParameters?SPARK_SCRIPT=simple_spark_wordcount.py&RESOURCE_PROFILE=minimal"

sleep 3

BUILD_NUM=$(curl -s -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
  "${JENKINS_URL}/job/${JOB_NAME}/lastBuild/buildNumber")

echo "✓ Build triggered: #${BUILD_NUM}"
echo ""

# Summary
echo "============================================"
echo "✓✓✓ JENKINS PIPELINE UPDATED"
echo "============================================"
echo ""
echo "Improvements in Fixed Pipeline:"
echo "  ✓ Resource profiles (minimal/standard/large)"
echo "  ✓ Pre-flight system checks"
echo "  ✓ Better error handling"
echo "  ✓ 10-minute timeout (vs 5 minutes)"
echo "  ✓ Memory check before running"
echo "  ✓ Improved Spark configuration"
echo "  ✓ Better logging and output"
echo ""
echo "New Parameters:"
echo "  • SPARK_SCRIPT: Which script to run"
echo "  • RESOURCE_PROFILE: minimal/standard/large"
echo ""
echo "Resource Profiles:"
echo "  minimal:  1 executor, 512M memory, 1 core"
echo "  standard: 1 executor, 1G memory, 1 core"
echo "  large:    2 executors, 2G memory, 2 cores"
echo ""
echo "Monitor Build:"
echo "  ${JENKINS_URL}/job/${JOB_NAME}/${BUILD_NUM}/console"
echo ""
echo "Expected duration: 2-3 minutes"
echo "============================================"

# Cleanup
rm -f /tmp/pipeline_config_updated.xml /tmp/jenkins-cookie

exit 0

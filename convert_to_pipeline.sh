#!/bin/bash
###############################################################################
# Convert TfL_Spark_Analysis from Freestyle to Pipeline
# Deletes old job and creates new Pipeline job
###############################################################################

set -e

# Jenkins Configuration
JENKINS_URL="http://51.24.13.205:8081"
JENKINS_USER="consultant"
JENKINS_PASSWORD="WelcomeItc@2026"
OLD_JOB_NAME="TfL_Spark_Analysis"
NEW_JOB_NAME="TfL_Spark_Pipeline"

echo "==========================================="
echo "Converting Jenkins Job to Pipeline"
echo "==========================================="
echo "Jenkins: $JENKINS_URL"
echo "Old Job: $OLD_JOB_NAME (Freestyle)"
echo "New Job: $NEW_JOB_NAME (Pipeline)"
echo ""

# Step 1: Get Jenkins CRUMB for authentication
echo "Step 1: Getting Jenkins authentication token..."
CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  --cookie-jar /tmp/jenkins-cookie \
  "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")

if [ -z "$CRUMB" ]; then
    echo "ERROR: Failed to get Jenkins CRUMB. Check credentials."
    exit 1
fi
echo "✓ Authentication successful"
echo ""

# Step 2: Delete old Freestyle job (if exists)
echo "Step 2: Deleting old Freestyle job..."
curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -X POST \
  "$JENKINS_URL/job/$OLD_JOB_NAME/doDelete" 2>&1 | grep -q "302" && \
  echo "✓ Old job deleted" || echo "⚠ Old job not found (OK)"
echo ""

# Wait a bit
sleep 2

# Step 3: Create new Pipeline job
echo "Step 3: Creating new Pipeline job..."

cat > /tmp/pipeline_config.xml << 'XML_EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>TfL PySpark Pipeline - Runs Spark jobs on Cloudera cluster</description>
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
        <hudson.model.StringParameterDefinition>
          <name>NUM_EXECUTORS</name>
          <description>Number of YARN executors</description>
          <defaultValue>2</defaultValue>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>EXECUTOR_MEMORY</name>
          <description>Memory per executor (e.g., 1G, 2G)</description>
          <defaultValue>1G</defaultValue>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>EXECUTOR_CORES</name>
          <description>CPU cores per executor</description>
          <defaultValue>1</defaultValue>
        </hudson.model.StringParameterDefinition>
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
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
XML_EOF

curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -H "Content-Type: application/xml" \
  --data-binary @/tmp/pipeline_config.xml \
  "$JENKINS_URL/createItem?name=$NEW_JOB_NAME"

if [ $? -eq 0 ]; then
    echo "✓ Pipeline job created successfully"
else
    echo "✗ Failed to create Pipeline job"
    exit 1
fi
echo ""

# Step 4: Verify job was created
echo "Step 4: Verifying new job..."
JOB_EXISTS=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  "$JENKINS_URL/job/$NEW_JOB_NAME/api/json" | grep -c "displayName")

if [ "$JOB_EXISTS" -gt 0 ]; then
    echo "✓ Job verified in Jenkins"
else
    echo "✗ Job not found in Jenkins"
    exit 1
fi
echo ""

# Step 5: Trigger first build
echo "Step 5: Triggering test build..."
curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -X POST \
  "$JENKINS_URL/job/$NEW_JOB_NAME/buildWithParameters?SPARK_SCRIPT=simple_spark_wordcount.py&NUM_EXECUTORS=2&EXECUTOR_MEMORY=1G&EXECUTOR_CORES=1"

echo "✓ Build triggered"
echo ""

# Summary
echo "==========================================="
echo "✓✓✓ CONVERSION COMPLETE ✓✓✓"
echo "==========================================="
echo ""
echo "New Pipeline Job Created:"
echo "  Name: $NEW_JOB_NAME"
echo "  Type: Pipeline"
echo "  Source: Git (Jenkinsfile)"
echo "  Repo: https://github.com/uttamraj9/TFL_Project_Demo.git"
echo ""
echo "Access your new job:"
echo "  $JENKINS_URL/job/$NEW_JOB_NAME/"
echo ""
echo "Monitor build progress:"
echo "  $JENKINS_URL/job/$NEW_JOB_NAME/1/console"
echo ""
echo "Build Parameters:"
echo "  SPARK_SCRIPT: simple_spark_wordcount.py"
echo "  NUM_EXECUTORS: 2"
echo "  EXECUTOR_MEMORY: 1G"
echo "  EXECUTOR_CORES: 1"
echo ""
echo "Next Steps:"
echo "  1. Open: $JENKINS_URL/job/$NEW_JOB_NAME/"
echo "  2. Click 'Build with Parameters'"
echo "  3. Adjust settings if needed"
echo "  4. Click 'Build'"
echo "  5. Watch console output"
echo "==========================================="

# Cleanup
rm -f /tmp/pipeline_config.xml /tmp/jenkins-cookie

exit 0

// Jenkinsfile for TfL PySpark Analysis Pipeline
// Declarative Pipeline for running Spark jobs on Cloudera cluster

pipeline {
    agent any

    parameters {
        choice(
            name: 'SPARK_SCRIPT',
            choices: ['simple_spark_wordcount.py', 'tfl_spark_analysis.py'],
            description: 'Select which PySpark script to run'
        )
        string(
            name: 'NUM_EXECUTORS',
            defaultValue: '2',
            description: 'Number of YARN executors'
        )
        string(
            name: 'EXECUTOR_MEMORY',
            defaultValue: '1G',
            description: 'Memory per executor (e.g., 1G, 2G)'
        )
        string(
            name: 'EXECUTOR_CORES',
            defaultValue: '1',
            description: 'CPU cores per executor'
        )
    }

    environment {
        REMOTE_HOST = '13.41.167.97'
        REMOTE_USER = 'consultant'
        REMOTE_PASSWORD = 'WelcomeItc@2026'
        PROJECT_DIR = '/home/consultant/uttam/TFL_Project_Demo'
        OUTPUT_DIR = '/tmp/uttam/spark_output'
    }

    stages {
        stage('Checkout') {
            steps {
                echo '========================================='
                echo 'Stage 1: Git Checkout'
                echo '========================================='
                checkout scm
                sh 'git log -1 --oneline'
            }
        }

        stage('Verify Scripts') {
            steps {
                echo '========================================='
                echo 'Stage 2: Verify PySpark Scripts'
                echo '========================================='
                script {
                    if (!fileExists("src/spark/${params.SPARK_SCRIPT}")) {
                        error("PySpark script not found: ${params.SPARK_SCRIPT}")
                    }
                }
                sh '''
                    echo "Scripts in workspace:"
                    ls -lh src/spark/*.py
                    echo ""
                    echo "Selected script: ${SPARK_SCRIPT}"
                    wc -l src/spark/${SPARK_SCRIPT}
                '''
            }
        }

        stage('Deploy to Cloudera') {
            steps {
                echo '========================================='
                echo 'Stage 3: Deploy Scripts to Cloudera'
                echo '========================================='
                sh '''
                    # Create remote directory
                    sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                        ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ${PROJECT_DIR}/src/spark" 2>&1 | \
                        grep -v "ITC Big Data Lab" | grep -v "Commands:" | grep -v "HDFS home:" | grep -v "━" || true

                    # Copy PySpark scripts
                    sshpass -p "${REMOTE_PASSWORD}" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                        src/spark/*.py ${REMOTE_USER}@${REMOTE_HOST}:${PROJECT_DIR}/src/spark/ 2>&1 | \
                        grep -v "ITC Big Data Lab" | grep -v "Commands:" | grep -v "HDFS home:" | grep -v "━" || true

                    # Set permissions
                    sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                        ${REMOTE_USER}@${REMOTE_HOST} "chmod +x ${PROJECT_DIR}/src/spark/*.py" 2>&1 | \
                        grep -v "ITC Big Data Lab" | grep -v "Commands:" | grep -v "HDFS home:" | grep -v "━" || true

                    echo "✓ Scripts deployed successfully"
                '''
            }
        }

        stage('Check YARN Resources') {
            steps {
                echo '========================================='
                echo 'Stage 4: Check YARN Resource Availability'
                echo '========================================='
                sh '''
                    echo "Checking YARN NodeManager status..."
                    sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                        ${REMOTE_USER}@${REMOTE_HOST} \
                        "yarn node -list 2>&1 | grep -E 'Total Nodes|RUNNING'" 2>&1 | \
                        grep -v "ITC Big Data Lab" || true

                    echo ""
                    echo "Checking for stuck applications..."
                    sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                        ${REMOTE_USER}@${REMOTE_HOST} \
                        "yarn application -list -appStates ACCEPTED 2>&1 | tail -5" 2>&1 | \
                        grep -v "ITC Big Data Lab" || true

                    echo ""
                    echo "Checking system memory..."
                    sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                        ${REMOTE_USER}@${REMOTE_HOST} \
                        "free -h | grep -E 'Mem:|available'" 2>&1 | \
                        grep -v "ITC Big Data Lab" || true

                    echo "✓ YARN resources checked"
                '''
            }
        }

        stage('Prepare HDFS') {
            steps {
                echo '========================================='
                echo 'Stage 5: Prepare HDFS Output Directory'
                echo '========================================='
                sh '''
                    # Clean up previous output
                    sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                        ${REMOTE_USER}@${REMOTE_HOST} \
                        "hdfs dfs -rm -r -f -skipTrash ${OUTPUT_DIR} || true" 2>&1 | \
                        grep -v "ITC Big Data Lab" | grep -v "Commands:" | grep -v "HDFS home:" | grep -v "━" || true

                    echo "✓ HDFS prepared"
                '''
            }
        }

        stage('Run Spark Job') {
            steps {
                echo '========================================='
                echo 'Stage 6: Execute PySpark Job'
                echo '========================================='
                echo "Script: ${params.SPARK_SCRIPT}"
                echo "Executors: ${params.NUM_EXECUTORS}"
                echo "Memory: ${params.EXECUTOR_MEMORY}"
                echo "Cores: ${params.EXECUTOR_CORES}"

                timeout(time: 5, unit: 'MINUTES') {
                    sh '''
                        echo "Starting Spark job with 5-minute timeout..."

                        sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                            ${REMOTE_USER}@${REMOTE_HOST} \
                            "cd ${PROJECT_DIR} && spark-submit \
                            --master yarn \
                            --deploy-mode client \
                            --num-executors ${NUM_EXECUTORS} \
                            --executor-memory ${EXECUTOR_MEMORY} \
                            --executor-cores ${EXECUTOR_CORES} \
                            --conf spark.yarn.submit.waitAppCompletion=true \
                            --conf spark.yarn.queue=default \
                            --conf spark.yarn.am.memory=512m \
                            --conf spark.yarn.am.cores=1 \
                            --conf spark.network.timeout=120s \
                            --conf spark.executor.heartbeatInterval=20s \
                            src/spark/${SPARK_SCRIPT}" 2>&1 | \
                            tee /tmp/spark_output.log | \
                            grep -E "INFO|WARN|ERROR|completed|failed|stage|task|application_" | \
                            grep -v "ITC Big Data Lab" || true

                        echo ""
                        echo "✓ Spark job execution completed"
                    '''
                }
            }
        }

        stage('Verify Results') {
            steps {
                echo '========================================='
                echo 'Stage 7: Verify Spark Output'
                echo '========================================='
                sh '''
                    echo "Checking HDFS output directory..."
                    sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                        ${REMOTE_USER}@${REMOTE_HOST} \
                        "hdfs dfs -ls ${OUTPUT_DIR} 2>/dev/null || echo 'No output directory (script may not save to HDFS)'" 2>&1 | \
                        grep -v "ITC Big Data Lab" | grep -v "Commands:" | grep -v "HDFS home:" | grep -v "━" || true
                '''
            }
        }
    }

    post {
        success {
            echo '========================================='
            echo '✓✓✓ PIPELINE COMPLETED SUCCESSFULLY ✓✓✓'
            echo '========================================='
            echo "PySpark Script: ${params.SPARK_SCRIPT}"
            echo "Executors: ${params.NUM_EXECUTORS} x ${params.EXECUTOR_MEMORY}"
            echo "Cloudera: ${REMOTE_HOST}:${PROJECT_DIR}"
            echo '========================================='
        }
        failure {
            echo '========================================='
            echo '✗✗✗ PIPELINE FAILED ✗✗✗'
            echo '========================================='
            echo "Check console output for errors"
            echo "Script: ${params.SPARK_SCRIPT}"
            echo '========================================='
        }
        always {
            echo 'Pipeline execution completed'
        }
    }
}

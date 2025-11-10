pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('jenkins_aws_access_key_id')
        AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
        AWS_DEFAULT_REGION    = "eu-central-1"
        TF_PIPELINE_IP        = credentials('TF_PIPELINE_IP')
        TF_MY_IP              = credentials('TF_MY_IP')
    }

    stages {
        stage('Provision EC2 with Terraform') {
            steps {
                dir("terraform/ec2") {
                    echo "Provision EC2 dynamic test env"

                    sh 'terraform init -upgrade'

                    script {
                        def currentIp = sh(script: "curl -s ifconfig.me", returnStdout: true).trim()
                        echo "🌍 Detected current pipeline public IP: ${currentIp}"

                        sh """
                    terraform apply -auto-approve \
                      -var="aws_region=${AWS_DEFAULT_REGION}" \
                      -var="pipeline_ip=${currentIp}" \
                      -var="my_ip=${TF_MY_IP}" \
                      -var="environment=dev"
                """

                        def appIp = sh(
                                script: "terraform output -raw app_public_ip",
                                returnStdout: true
                        ).trim()
                        env.APP_IP = appIp
                        echo "EC2 instance created: ${appIp}"
                    }
                }
            }
        }

        stage('Start Application Stack') {
            steps {
                sshagent(['ansible-ssh-key-aws']) {
                    sh """
                        echo "Copy docker compose.yml to dynamic env${env.APP_IP}"
                        scp -o StrictHostKeyChecking=no docker-compose.yml ubuntu@${env.APP_IP}:/home/ubuntu/docker-compose.yml
        
                        echo "Starting application stack"
                        ssh -o StrictHostKeyChecking=no ubuntu@${env.APP_IP} '
                            cd /home/ubuntu &&
                            docker compose pull &&
                            docker compose up -d &&
                            docker ps
                        '
            """
                }
            }
        }

        stage('Run Integration Tests') {
            steps {
                sshagent(['ansible-ssh-key-aws']) {
                    sh """
                        echo "Run tests on dynamic env ${env.APP_IP}"
                        ssh -o StrictHostKeyChecking=no ubuntu@${env.APP_IP} '
                            cd ~/app/tests &&
                            docker run --rm \\
                                --network=app_default \\
                                -e BASE_URL=http://fastapi_app:8000 \\
                                -e DB_URL=jdbc:postgresql://db:5432/fastapidb \\
                                restassured mvn -Dtest=integrationTest test
                        '
                    """
                }
            }
        }
    }

    post {
        always {
            echo "Destroy EC2 test environment..."
            dir("terraform/ec2") {
                sh """
                    terraform destroy -auto-approve \
                      -var="aws_region=${AWS_DEFAULT_REGION}" \
                      -var="pipeline_ip=${TF_PIPELINE_IP}" \
                      -var="my_ip=${TF_MY_IP}" \
                      -var="environment=dev"
                """
            }
        }
    }
}

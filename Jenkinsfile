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
                    echo "Provisioning EC2 test environment..."

                    sh 'terraform init -upgrade'

                    sh """
                        terraform apply -auto-approve \
                          -var="aws_access_key=${AWS_ACCESS_KEY_ID}" \
                          -var="aws_secret_key=${AWS_SECRET_ACCESS_KEY}" \
                          -var="aws_region=${AWS_DEFAULT_REGION}" \
                          -var="pipeline_ip=${TF_PIPELINE_IP}" \
                          -var="my_ip=${TF_MY_IP}" \
                          -var="environment=dev"
                    """

                    script {
                        def appIp = sh(
                                script: "terraform output -raw app_public_ip",
                                returnStdout: true
                        ).trim()
                        env.APP_IP = appIp
                        echo "✅ EC2 instance created: ${appIp}"
                    }
                }
            }
        }
    }

    post {
        always {
            echo "🧹 Destroy EC2 test environment..."
            dir("terraform/ec2") {
                sh """
                    terraform destroy -auto-approve \
                      -var="aws_access_key=${AWS_ACCESS_KEY_ID}" \
                      -var="aws_secret_key=${AWS_SECRET_ACCESS_KEY}" \
                      -var="aws_region=${AWS_DEFAULT_REGION}" \
                      -var="pipeline_ip=${TF_PIPELINE_IP}" \
                      -var="my_ip=${TF_MY_IP}" \
                      -var="environment=dev"
                """
            }
        }
    }
}

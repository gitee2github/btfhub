pipeline {
    agent any

    parameters {
        string(name: 'BTFHUB_ARCHIVE_REPO_URL',
            description: 'URL of the archive repository',
            defaultValue: 'https://gitee.com/openeuler/btfhub-archive.git')
        string(name: 'BTFHUB_ARCHIVE_BUILD_BRANCH',
            description: 'Branch of the archive repository to build upon',
            defaultValue: 'next')
        string(name: 'BTFHUB_GIT_AUTHOR_NAME',
            description: 'Author name for Git commits',
            defaultValue: 'Yang Hanlin')
        string(name: 'BTFHUB_GIT_AUTHOR_EMAIL',
            description: 'Author email for Git commits',
            defaultValue: 'mattoncis@hotmail.com')
        string(name: 'BTFHUB_GIT_CREDENTIAL_ID',
            description: 'Credential ID for Git-related actions',
            defaultValue: 'gitee-hanlinyang-username-password')
    }

    stages {
        stage('Check out & configure repositories') {
            steps {
                dir('btfhub') {
                    checkout scm
                }
                dir('btfhub-archive') {
                    checkout scmGit(
                        branches: [[name: "*/${params.BTFHUB_ARCHIVE_BUILD_BRANCH}"]],
                        userRemoteConfigs: [[
                            name: 'origin',
                            url: params.BTFHUB_ARCHIVE_REPO_URL]],
                        extensions: [
                            cloneOption(shallow: true),
                            localBranch() ])

                    sh "git branch --set-upstream-to origin/${params.BTFHUB_ARCHIVE_BUILD_BRANCH}"
                    sh "git config --local user.name '${params.BTFHUB_GIT_AUTHOR_NAME}'"
                    sh "git config --local user.email '${params.BTFHUB_GIT_AUTHOR_EMAIL}'"
                }
            }
        }

        stage('Prepare environment') {
            steps {
                dir('btfhub') {
                    sh 'docker build -t openeuler-btfhub-ci-builder - < tools/ci/Dockerfile'
                }

                sh 'uname -a'
                sh 'docker version'
                sh 'git --version'

                sh '''
                docker run --rm openeuler-btfhub-ci-builder bash -c " \
                    set -x && \
                    uname -a && \
                    clang --version && \
                    find --version && \
                    git --version && \
                    go version && \
                    jq --version && \
                    make --version && \
                    pahole --version && \
                    rsync --version && \
                    xargs --version && \
                    xz --version"
                '''
            }
        }

        stage('Generate BTF files') {
            steps {
                sh '''
                docker run --rm -v "$(pwd):/workspace" openeuler-btfhub-ci-builder bash -c " \
                    set -x && \
                    cd /workspace/btfhub && \
                    make bring && \
                    make && \
                    ./btfhub -distro openEuler && \
                    make take"
                '''
            }
        }

        stage('Commit & push to BTFHub Archive') {
            steps {
                dir('btfhub-archive') {
                    sh 'git add -A'
                    sh 'git status'
                    sh '''
                    git diff-index --quiet HEAD || \
                    ( printf '%s\\n' \
                        "Update BTFHub Archive" \
                        "" \
                        "This commit is created by an automated build process; see also <$BUILD_URL>." \
                    | git commit -F - ) && \
                    git log -1
                    '''

                    withCredentials([
                        gitUsernamePassword(credentialsId: params.BTFHUB_GIT_CREDENTIAL_ID) ]) {
                        sh 'git push'
                    }
                }
            }
        }

        stage('Create PR') {
            steps {
                withCredentials([ usernamePassword(
                    credentialsId: params.BTFHUB_GIT_CREDENTIAL_ID,
                    passwordVariable: 'BTFHUB_GITEE_API_TOKEN') ]) {
                    sh '''
                    docker run --rm -v "$(pwd):/workspace" \
                        -e BTFHUB_GITEE_API_TOKEN \
                        -e JOB_NAME \
                        -e JOB_URL \
                        openeuler-btfhub-ci-builder bash -c " \
                            set -x && \
                            cd /workspace/btfhub-archive && \
                            ../btfhub/tools/ci/create-pr.sh"
                    '''
                }
            }
        }
    }

    post {
        cleanup {
            cleanWs()
        }
    }
}

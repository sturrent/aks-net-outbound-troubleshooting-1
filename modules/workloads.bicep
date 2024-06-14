@secure()
param kubeConfig string

provider kubernetes with {
  namespace: 'default'
  kubeConfig: kubeConfig
}

resource coreConfigMap_dbMonitorConfig 'core/ConfigMap@v1' = {
  metadata: {
    name: 'db-monitor-config'
    namespace: 'default'
  }
  data: {
    pghost: 'db1.postgresdb1-workbench-lab1.private.postgres.database.azure.com'
    pguser: 'admindb'
    pgpass: 'T3mp0r4l'
    dbname: 'postgres'
  }
}

resource appsDeployment_dbCheck 'apps/Deployment@v1' = {
  metadata: {
    name: 'db-check'
    labels: {
      app: 'db-check'
    }
  }
  spec: {
    replicas: 1
    selector: {
      matchLabels: {
        app: 'db-check'
      }
    }
    template: {
      metadata: {
        labels: {
          app: 'db-check'
        }
      }
      spec: {
        containers: [
          {
            name: 'db-check'
            image: 'sturrent/psql-monitor:latest'
            env: [
              {
                name: 'PGHOST'
                valueFrom: {
                  configMapKeyRef: {
                    name: 'db-monitor-config'
                    key: 'pghost'
                  }
                }
              }
              {
                name: 'PGUSER'
                valueFrom: {
                  configMapKeyRef: {
                    name: 'db-monitor-config'
                    key: 'pguser'
                  }
                }
              }
              {
                name: 'PGPASS'
                valueFrom: {
                  configMapKeyRef: {
                    name: 'db-monitor-config'
                    key: 'pgpass'
                  }
                }
              }
              {
                name: 'DBNAME'
                valueFrom: {
                  configMapKeyRef: {
                    name: 'db-monitor-config'
                    key: 'dbname'
                  }
                }
              }
            ]
          }
        ]
      }
    }
  }
}

resource coreServiceAccount_runner1 'core/ServiceAccount@v1' = {
  metadata: {
    name: 'runner1'
    namespace: 'kube-system'
  }
}

resource rbacAuthorizationK8sIoClusterRoleBinding_runner1Admin 'rbac.authorization.k8s.io/ClusterRoleBinding@v1' = {
  metadata: {
    name: 'runner1-admin'
  }
  subjects: [
    {
      kind: 'ServiceAccount'
      name: 'runner1'
      namespace: 'kube-system'
    }
  ]
  roleRef: {
    kind: 'ClusterRole'
    name: 'admin'
    apiGroup: 'rbac.authorization.k8s.io'
  }
}

resource appsDeployment_runner1 'apps/Deployment@v1' = {
  metadata: {
    name: 'runner1'
    namespace: 'kube-system'
    labels: {
      app: 'runner1'
    }
  }
  spec: {
    replicas: 1
    selector: {
      matchLabels: {
        app: 'runner1'
      }
    }
    template: {
      metadata: {
        labels: {
          app: 'runner1'
        }
      }
      spec: {
        containers: [
          {
            name: 'runner1'
            image: 'sturrent/runner1:latest'
          }
        ]
        serviceAccountName: 'runner1'
      }
    }
  }
}

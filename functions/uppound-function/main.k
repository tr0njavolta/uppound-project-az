import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1
import models.io.uppound.app.v1alpha1 as appv1alpha1
import models.io.crossplane.kubernetes.v1alpha2 as k8sv1alpha2

oxr = appv1alpha1.XApp {**option("params").oxr}
_ocds = option("params").ocds
_dxr = option("params").dxr
dcds = option("params").dcds
_er = option("params")?.extraResources

_metadata = lambda name: str -> any {
    {
        name: name
        annotations = {"krm.kcl.dev/composition-resource-name" = name}
    }
}

_items = [
    # Network
    {
        apiVersion: "azure.platform.upbound.io/v1alpha1"
        kind: "XNetwork"
        metadata: {
            labels: {
                "networks.azure.platform.upbound.io/network-id": oxr.metadata.name
            }
            name: "{}-network".format(oxr.metadata.name)
        }
        spec: {
            parameters: {
                providerConfigName: "example"
                id: oxr.metadata.name
                region: oxr.spec.parameters.region
            }
        }
    }
    # AKS Cluster
    {
        apiVersion: "azure.platform.upbound.io/v1alpha1"
        kind: "XAKS"
        metadata: {
            name: "{}-azure-cluster".format(oxr.metadata.name)
        }
        spec: {
            writeConnectionSecretToRef: {
                name: oxr.spec.writeConnectionSecretToRef.name
                namespace: oxr.spec.writeConnectionSecretToRef.namespace
            }
            parameters: {
                providerConfigName: "example"
                id: oxr.metadata.name
                nodes: {
                    count: oxr.spec.parameters.nodes.count
                    instanceType: oxr.spec.parameters.nodes.instanceType
                }
                region: oxr.spec.parameters.region
                version: oxr.spec.parameters.version
            }
        }
    }
    # Frontend Deployment
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-frontend-deployment".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "apps/v1"
                    kind: "Deployment"
                    metadata: {
                        name: "{}-frontend-deployment".format(oxr.metadata.name)
                        namespace: "default"
                    }
                    spec: {
                        replicas: 1
                        selector: {
                            matchLabels: {
                                app: "frontend"
                            }
                        }
                        template: {
                            metadata: {
                                labels: {
                                    app: "frontend"
                                }
                            }
                            spec: {
                                containers: [
                                    {
                                        name: "frontend"
                                        image: oxr.spec.parameters.containers[0].image
                                        ports: [
                                            {
                                                containerPort: 80
                                            }
                                        ]
                                        env: [
                                            {
                                                name: "REACT_APP_API_URL"
                                                value: "/api"
                                            }
                                        ]
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    }
    # Frontend Service
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-frontend-service".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "v1"
                    kind: "Service"
                    metadata: {
                        name: "{}-frontend-service".format(oxr.metadata.name)
                        namespace: "default"
                        annotations: {
                            "service.beta.kubernetes.io/azure-load-balancer-internal": "false"
                        }
                    }
                    spec: {
                        selector: {
                            app: "frontend"
                        }
                        ports: [
                            {
                                port: 80
                                targetPort: 80
                            }
                        ]
                        type: "LoadBalancer"
                    }
                }
            }
        }
    }
    # Backend Deployment
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-backend-deployment".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "apps/v1"
                    kind: "Deployment"
                    metadata: {
                        name: "{}-backend-deployment".format(oxr.metadata.name)
                        namespace: "default"
                    }
                    spec: {
                        replicas: 1
                        selector: {
                            matchLabels: {
                                app: "backend"
                            }
                        }
                        template: {
                            metadata: {
                                labels: {
                                    app: "backend"
                                }
                            }
                            spec: {
                                containers: [
                                    {
                                        name: "backend"
                                        image: oxr.spec.parameters.containers[1].image
                                        env: [
                                            {
                                                name: "DATABASE_URL"
                                                value: "postgres://postgres:postgres@{}-postgres-service:5432/uppound".format(oxr.metadata.name)
                                            }
                                            {
                                                name: "PORT"
                                                value: "3001"
                                            }
                                            {
                                                name: "DB_MAX_RETRIES"
                                                value: "15"
                                            }
                                            {
                                                name: "DB_RETRY_INTERVAL"
                                                value: "5000"
                                            }
                                        ]
                                        ports: [
                                            {
                                                containerPort: 3001
                                            }
                                        ]
                                        livenessProbe: {
                                            httpGet: {
                                                path: "/health"
                                                port: 3001
                                            }
                                            initialDelaySeconds: 20
                                            periodSeconds: 20
                                            timeoutSeconds: 5
                                            successThreshold: 1
                                            failureThreshold: 3
                                        }
                                        resources: {
                                            requests: {
                                                memory: "256Mi"
                                                cpu: "100m"
                                            }
                                            limits: {
                                                memory: "512Mi"
                                                cpu: "500m"
                                            }
                                        }
                                        volumeMounts: [
                                            {
                                                name: "uploads-volume"
                                                mountPath: "/app/uploads"
                                            }
                                            {
                                                name: "images-volume"
                                                mountPath: "/app/images"
                                            }
                                        ]
                                    }
                                ]
                                volumes: [
                                    {
                                        name: "uploads-volume"
                                        emptyDir: {}
                                    }
                                    {
                                        name: "images-volume"
                                        emptyDir: {}
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    }
    # Backend Service
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-backend-service".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "v1"
                    kind: "Service"
                    metadata: {
                        name: "{}-backend-service".format(oxr.metadata.name)
                        namespace: "default"
                    }
                    spec: {
                        selector: {
                            app: "backend"
                        }
                        ports: [
                            {
                                name: "api"
                                port: 3001
                                targetPort: 3001
                            }
                            {
                                name: "debug"
                                port: 3002
                                targetPort: 3001
                            }
                        ]
                        type: "ClusterIP"
                    }
                }
            }
        }
    }
    # PostgreSQL Deployment
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-postgres-deployment".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "apps/v1"
                    kind: "Deployment"
                    metadata: {
                        name: "{}-postgres-deployment".format(oxr.metadata.name)
                        namespace: "default"
                    }
                    spec: {
                        replicas: 1
                        selector: {
                            matchLabels: {
                                app: "postgres"
                            }
                        }
                        template: {
                            metadata: {
                                labels: {
                                    app: "postgres"
                                }
                            }
                            spec: {
                                containers: [
                                    {
                                        name: "postgres"
                                        image: "postgres:13.18"
                                        env: [
                                            {
                                                name: "POSTGRES_USER"
                                                value: "postgres"
                                            }
                                            {
                                                name: "POSTGRES_PASSWORD"
                                                value: "postgres"
                                            }
                                            {
                                                name: "POSTGRES_DB"
                                                value: "uppound"
                                            }
                                            {
                                                name: "POSTGRES_HOST_AUTH_METHOD"
                                                value: "trust"
                                            }
                                        ]
                                        ports: [
                                            {
                                                containerPort: 5432
                                            }
                                        ]
                                        volumeMounts: [
                                            {
                                                name: "postgres-data"
                                                mountPath: "/var/lib/postgresql/data"
                                                subPath: "postgres-db"
                                            }
                                            {
                                                name: "db-schema"
                                                mountPath: "/docker-entrypoint-initdb.d"
                                            }
                                        ]
                                        resources: {
                                            requests: {
                                                memory: "256Mi"
                                                cpu: "100m"
                                            }
                                            limits: {
                                                memory: "512Mi"
                                                cpu: "500m"
                                            }
                                        }
                                        readinessProbe: {
                                            exec: {
                                                command: ["pg_isready", "-U", "postgres"]
                                            }
                                            initialDelaySeconds: 5
                                            periodSeconds: 10
                                        }
                                        livenessProbe: {
                                            exec: {
                                                command: ["pg_isready", "-U", "postgres"]
                                            }
                                            initialDelaySeconds: 15
                                            periodSeconds: 20
                                        }
                                    }
                                ]
                                volumes: [
                                    {
                                        name: "postgres-data"
                                        emptyDir: {}
                                    }
                                    {
                                        name: "db-schema"
                                        configMap: {
                                            name: "db-schema"
                                        }
                                    }
                                ]                            }
                        }
                    }
                }
            }
        }
    }
    # PostgreSQL Service
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-postgres-service".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "v1"
                    kind: "Service"
                    metadata: {
                        name: "{}-postgres-service".format(oxr.metadata.name)
                        namespace: "default"
                    }
                    spec: {
                        selector: {
                            app: "postgres"
                        }
                        ports: [
                            {
                                port: 5432
                                targetPort: 5432
                            }
                        ]
                        type: "ClusterIP"
                    }
                }
            }
        }
    }
    # Database Schema ConfigMap
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-db-schema".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            forProvider: {
                manifest: {
                    apiVersion: "v1"
                    kind: "ConfigMap"
                    metadata: {
                        name: "db-schema"
                        namespace: "default"
                    }
                    data: {
                        "init.sql": """CREATE TABLE IF NOT EXISTS pets (
                      id SERIAL PRIMARY KEY,
                      name VARCHAR(255) NOT NULL,
                      species VARCHAR(100) NOT NULL,
                      breed VARCHAR(100),
                      age INT,
                      description TEXT,
                      image_url VARCHAR(255)
                    );
                    CREATE TABLE IF NOT EXISTS adoptions (
                      id SERIAL PRIMARY KEY,
                      pet_id INT REFERENCES pets(id),
                      applicant_name VARCHAR(255) NOT NULL,
                      email VARCHAR(255) NOT NULL,
                      phone VARCHAR(50),
                      message TEXT,
                      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    );
                    INSERT INTO pets (name, species, breed, age, description, image_url) VALUES
                    ('Hayden', 'Cat', 'Longhair domestic', 10, 'A sleepy, cuddly companion who can say "Hello" when she wants food.', 'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/hayden.jpg'),
                    ('Milo', 'Dog', 'English Springer Spaniel', 1, 'Sweet and energetic puppy who loves attention', 'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/milo.jpg'),
                    ('Phelix', 'Cat', 'Shorthair domestic', 1, 'Curious and playful kitten', 'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/phelix.jpg'),
                    ('Jerry', 'Small', 'Ferret', 100, 'A wizard turned into a ferret after a spell gone wrong.', 'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/jerry.jpg'),
                    ('Boogie', 'Dog', 'French Bulldog', 5, 'A lazy, loyal family dog', 'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/boogie.jpg'),
                    ('Artemis', 'Cat', 'Tabby', 6, 'Artemis is blinged-out. If you have to ask you can''t afford her', 'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/artemis.jpg'),
                    ('Simon', 'Cat', 'American Shorthair', 5, 'Cross-eyed and cuddly, Simon only has eyes for you', 'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/simon.jpg'),
                    ('Eva', 'Dog', 'Bearded Collie', 16, 'She isn''t just a good dog, she''s the best dog, and will not tolerate any other dog that gets in the way of that', 'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/eva.jpg'),
                    ('Rosie', 'Dog', 'Airedale', 5,'Rosie''s always up for an adventure... or a nap...','https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/rosie.jpg'),
                    ('Winnie', 'Dog', 'Mini Schauzer', 5,'Winnie *allegedly* commited some light breaking and entering for a PupCup' ,'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/winnie.jpg'),
                    ('Luffy', 'Cat', 'Tuxedo', 5,'Luffy''s always ready for a black-tie event' ,'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/luffy.jpg'),
                    ('Minik', 'Cat', 'Shorthair domestic', 6,'Minik loves treats, catnip, and controlling the weather with his mind' ,'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/minik.jpg'),
                    ('Mochi', 'Dog', 'Sharpei', 16, 'A handsome, well-dressed adventurer with a knack for finding the coziest cuddle spots', 'https://raw.githubusercontent.com/tr0njavolta/uppound-demo/main/images/mochi.jpg');"""
                    }
                }
            }
        }
    }
    # Nginx ConfigMap
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-nginx-config".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            forProvider: {
                manifest: {
                    apiVersion: "v1"
                    kind: "ConfigMap"
                    metadata: {
                        name: "{}-nginx-config".format(oxr.metadata.name)
                        namespace: "default"
                    }
                    data: {
                        "default.conf": """server {
    listen 80;
    listen [::]:80;
    server_name _;

    location / {
        proxy_pass http://{0}-frontend-service;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api {
        proxy_pass http://{0}-backend-service:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /health {
        access_log off;
        return 200 "healthy\\n";
    }
}"""
                    }
                }
            }
        }
    }
    # Nginx Deployment
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-nginx-deployment".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "apps/v1"
                    kind: "Deployment"
                    metadata: {
                        name: "{}-nginx-deployment".format(oxr.metadata.name)
                        namespace: "default"
                    }
                    spec: {
                        replicas: 1
                        selector: {
                            matchLabels: {
                                app: "nginx"
                            }
                        }
                        template: {
                            metadata: {
                                labels: {
                                    app: "nginx"
                                }
                            }
                            spec: {
                                containers: [
                                    {
                                        name: "nginx"
                                        image: "nginx:latest"
                                        ports: [
                                            {
                                                containerPort: 80
                                            }
                                        ]
                                        volumeMounts: [
                                            {
                                                name: "nginx-config"
                                                mountPath: "/etc/nginx/conf.d/default.conf"
                                                subPath: "default.conf"
                                            }
                                        ]
                                        livenessProbe: {
                                            httpGet: {
                                                path: "/health"
                                                port: 80
                                            }
                                            initialDelaySeconds: 15
                                            periodSeconds: 20
                                        }
                                        readinessProbe: {
                                            httpGet: {
                                                path: "/health"
                                                port: 80
                                            }
                                            initialDelaySeconds: 5
                                            periodSeconds: 10
                                        }
                                    }
                                ]
                                volumes: [
                                    {
                                        name: "nginx-config"
                                        configMap: {
                                            name: "{}-nginx-config".format(oxr.metadata.name)
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    }
    # Nginx Service
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-nginx-service".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "v1"
                    kind: "Service"
                    metadata: {
                        name: "{}-nginx-service".format(oxr.metadata.name)
                        namespace: "default"
                        annotations: {
                            "service.beta.kubernetes.io/azure-load-balancer-internal": "false"
                        }
                    }
                    spec: {
                        selector: {
                            app: "nginx"
                        }
                        ports: [
                            {
                                port: 80
                                targetPort: 80
                            }
                        ]
                        type: "LoadBalancer"
                    }
                }
            }
        }
    }
    # AKS Ingress
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-frontend-ingress".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "networking.k8s.io/v1"
                    kind: "Ingress"
                    metadata: {
                        name: "{}-frontend-ingress".format(oxr.metadata.name)
                        namespace: "default"
                        annotations: {
                            "kubernetes.io/ingress.class": "azure/application-gateway"
                            "appgw.ingress.kubernetes.io/ssl-redirect": "false"
                        }
                    }
                    spec: {
                        rules: [
                            {
                                http: {
                                    paths: [
                                        {
                                            path: "/api"
                                            pathType: "Prefix"
                                            backend: {
                                                service: {
                                                    name: "api-service"
                                                    port: {
                                                        number: 80
                                                    }
                                                }
                                            }
                                        }
                                        {
                                            path: "/"
                                            pathType: "Prefix"
                                            backend: {
                                                service: {
                                                    name: "{}-frontend-service".format(oxr.metadata.name)
                                                    port: {
                                                        number: 80
                                                    }
                                                }
                                            }
                                        }
                                    ]
                                }
                            }
                        ]
                    }
                }
            }
            
        }
    }
    # Backend Service Alias
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("backend-service-alias")
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "v1"
                    kind: "Service"
                    metadata: {
                        name: "backend"
                        namespace: "default"
                    }
                    spec: {
                        selector: {
                            app: "backend"
                        }
                        ports: [
                            {
                                name: "api"
                                port: 3001
                                targetPort: 3001
                            }
                        ]
                        type: "ClusterIP"
                    }
                }
            }
        }
    }
    # API Service ConfigMap
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-api-config".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            forProvider: {
                manifest: {
                    apiVersion: "v1"
                    kind: "ConfigMap"
                    metadata: {
                        name: "{}-api-config".format(oxr.metadata.name)
                        namespace: "default"
                    }
                    data: {
                        "default.conf": """server {
    listen 80;
    server_name _;

    location /api/ {
        rewrite ^/api(.*)$ $1 break;
        proxy_pass http://backend:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /health {
        proxy_pass http://backend:3001/health;
    }

    location = /api/health {
        proxy_pass http://backend:3001/health;
    }
}"""
                    }
                }
            }
        }
    }
    # API Service Deployment
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-api-deployment".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "apps/v1"
                    kind: "Deployment"
                    metadata: {
                        name: "{}-api-deployment".format(oxr.metadata.name)
                        namespace: "default"
                    }
                    spec: {
                        replicas: 1
                        selector: {
                            matchLabels: {
                                app: "api-proxy"
                            }
                        }
                        template: {
                            metadata: {
                                labels: {
                                    app: "api-proxy"
                                }
                            }
                            spec: {
                                containers: [
                                    {
                                        name: "nginx"
                                        image: "nginx:latest"
                                        ports: [
                                            {
                                                containerPort: 80
                                            }
                                        ]
                                        volumeMounts: [
                                            {
                                                name: "api-config"
                                                mountPath: "/etc/nginx/conf.d/default.conf"
                                                subPath: "default.conf"
                                            }
                                        ]
                                        livenessProbe: {
                                            httpGet: {
                                                path: "/api/health"
                                                port: 80
                                            }
                                            initialDelaySeconds: 15
                                            periodSeconds: 20
                                        }
                                        readinessProbe: {
                                            httpGet: {
                                                path: "/api/health"
                                                port: 80
                                            }
                                            initialDelaySeconds: 5
                                            periodSeconds: 10
                                        }
                                    }
                                ]
                                volumes: [
                                    {
                                        name: "api-config"
                                        configMap: {
                                            name: "{}-api-config".format(oxr.metadata.name)
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    }
    # API Service
    {
        apiVersion: "kubernetes.crossplane.io/v1alpha1"
        kind: "Object"
        metadata: _metadata("{}-api-service".format(oxr.metadata.name))
        spec: {
            providerConfigRef: {
                name: oxr.metadata.name
            }
            readiness: {
                policy: "DeriveFromObject"
            }
            forProvider: {
                manifest: {
                    apiVersion: "v1"
                    kind: "Service"
                    metadata: {
                        name: "api-service"
                        namespace: "default"
                    }
                    spec: {
                        selector: {
                            app: "api-proxy"
                        }
                        ports: [
                            {
                                port: 80
                                targetPort: 80
                            }
                        ]
                        type: "ClusterIP"
                    }
                }
            }
        }
    }
]

items = _items

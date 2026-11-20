### 2026-11-20T12:28:04+01:00  (host: jozsef-nagy-nb02)
$ kind create cluster --config deployment/kind-config.yaml --name mst2 && kubectl config current-context && kubectl get nodes && kubectl get storageclass
Creating cluster "mst2" ...
 • Ensuring node image (kindest/node:v1.37.0) 🖼️  ...
 ✓ Ensuring node image (kindest/node:v1.37.0) 🖼️
 • Preparing nodes 📦   ...
 ✓ Preparing nodes 📦 
 • Writing configuration 📜  ...
 ✓ Writing configuration 📜
 • Starting control-plane 🕹️  ...
 ✓ Starting control-plane 🕹️
 • Installing CNI 🔌  ...
 ✓ Installing CNI 🔌
 • Installing StorageClass 💾  ...
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-mst2"
You can now use your cluster with:

kubectl cluster-info --context kind-mst2

Have a nice day! 👋
kind-mst2
NAME                 STATUS     ROLES           AGE   VERSION
mst2-control-plane   NotReady   control-plane   4s    v1.37.0
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  1s
[exit code: 0]

### 2026-11-20T12:28:17+01:00  (host: jozsef-nagy-nb02)
$ sed -i 's#stefanprodan/podinfo:6.17.0#stefanprodan/podinfo:6.14.1#' deployment/deployment.yaml && grep -n 'podinfo:' deployment/deployment.yaml
38:          image: stefanprodan/podinfo:6.14.1
[exit code: 0]

### 2026-11-20T12:28:22+01:00  (host: jozsef-nagy-nb02)
$ kubectl apply -k deployment/ && kubectl -n mst rollout status deploy/podinfo --timeout=180s && kubectl -n mst get pods,svc,pvc -o wide
namespace/mst created
service/podinfo created
persistentvolumeclaim/podinfo-data created
deployment.apps/podinfo created
Waiting for deployment "podinfo" rollout to finish: 0 of 1 updated replicas are available...
deployment "podinfo" successfully rolled out
NAME                           READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
pod/podinfo-7486c4bcb7-9lqh6   1/1     Running   0          17s   10.244.0.6   mst2-control-plane   <none>           <none>

NAME              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE   SELECTOR
service/podinfo   ClusterIP   10.96.30.213   <none>        9898/TCP   17s   app.kubernetes.io/name=podinfo

NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/podinfo-data   Bound    pvc-4e15b017-975b-4dac-8878-d7ad7b14b6f9   1Gi        RWO            standard       <unset>                 17s   Filesystem
[exit code: 0]

### 2026-11-20T12:28:53+01:00  (host: jozsef-nagy-nb02)
$ curl -sS -i http://127.0.0.1:9898/readyz; curl -sS http://127.0.0.1:9898/version
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
X-Content-Type-Options: nosniff
Date: Fri, 20 Nov 2026 11:28:53 GMT
Content-Length: 20

{
  "status": "OK"
}{
  "commit": "eec06d1ea459af4cb4e10e806f8be7c7bd58b361",
  "version": "6.14.1"
}[exit code: 0]

### 2026-11-20T12:28:58+01:00  (host: jozsef-nagy-nb02)
$ kubectl -n mst run netcheck --rm -i --restart=Never --image=curlimages/curl:8.17.0 -- curl -sS -i http://podinfo:9898/readyz
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
X-Content-Type-Options: nosniff
Date: Fri, 20 Nov 2026 11:29:02 GMT
Content-Length: 20

{
  "status": "OK"
}All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
pod "netcheck" deleted from mst namespace
[exit code: 0]

### 2026-11-20T12:29:05+01:00  (host: jozsef-nagy-nb02)
$ curl -sS --data-binary @testdata/record.txt http://127.0.0.1:9898/store | grep -o '[0-9a-f]\{40\}' | tee /tmp/podinfo-hash.txt; sha1sum testdata/record.txt
b8e715ae1a133891a61753cfa81fb2d5b6def9b1
b8e715ae1a133891a61753cfa81fb2d5b6def9b1  testdata/record.txt
[exit code: 0]

### 2026-11-20T12:29:18+01:00  (host: jozsef-nagy-nb02)
$ curl -sS http://127.0.0.1:9898/store/$HASH | cmp - testdata/record.txt && echo MATCH
MATCH
[exit code: 0]

### 2026-11-20T12:29:23+01:00  (host: jozsef-nagy-nb02)
$ kubectl -n mst get pod -l app.kubernetes.io/name=podinfo -o custom-columns=POD:.metadata.name,UID:.metadata.uid; kubectl -n mst delete pod -l app.kubernetes.io/name=podinfo --wait=true && kubectl -n mst wait pod -l app.kubernetes.io/name=podinfo --for=condition=Ready --timeout=180s; kubectl -n mst get pod -l app.kubernetes.io/name=podinfo -o custom-columns=POD:.metadata.name,UID:.metadata.uid
POD                        UID
podinfo-7486c4bcb7-9lqh6   dd56d416-e238-427b-b58e-63c604e48a5f
pod "podinfo-7486c4bcb7-9lqh6" deleted from mst namespace
pod/podinfo-7486c4bcb7-xg8h6 condition met
POD                        UID
podinfo-7486c4bcb7-xg8h6   42ccf9b1-09e8-4b0d-82bc-4363c7879c12
[exit code: 0]

### 2026-11-20T12:29:44+01:00  (host: jozsef-nagy-nb02)
$ curl -sS http://127.0.0.1:9898/store/$HASH | cmp - testdata/record.txt && echo MATCH
MATCH
[exit code: 0]

### 2026-11-20T12:29:51+01:00  (host: jozsef-nagy-nb02)
$ curl -sS http://127.0.0.1:9898/version; sed -i 's#stefanprodan/podinfo:6.14.1#stefanprodan/podinfo:6.17.0#' deployment/deployment.yaml && grep -n 'podinfo:' deployment/deployment.yaml; kubectl diff -k deployment/
{
  "commit": "eec06d1ea459af4cb4e10e806f8be7c7bd58b361",
  "version": "6.14.1"
}38:          image: stefanprodan/podinfo:6.17.0
diff -u -N /tmp/LIVE-2190440097/apps.v1.Deployment.mst.podinfo /tmp/MERGED-1175537558/apps.v1.Deployment.mst.podinfo
--- /tmp/LIVE-2190440097/apps.v1.Deployment.mst.podinfo	2026-11-20 12:29:51.562009867 +0100
+++ /tmp/MERGED-1175537558/apps.v1.Deployment.mst.podinfo	2026-11-20 12:29:51.563009876 +0100
@@ -6,7 +6,7 @@
     kubectl.kubernetes.io/last-applied-configuration: |
       {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"labels":{"app.kubernetes.io/name":"podinfo"},"name":"podinfo","namespace":"mst"},"spec":{"replicas":1,"selector":{"matchLabels":{"app.kubernetes.io/name":"podinfo"}},"strategy":{"type":"Recreate"},"template":{"metadata":{"labels":{"app.kubernetes.io/name":"podinfo"}},"spec":{"containers":[{"args":["--port=9898","--data-path=/data","--level=info"],"command":["./podinfo"],"image":"stefanprodan/podinfo:6.14.1","imagePullPolicy":"IfNotPresent","livenessProbe":{"httpGet":{"path":"/healthz","port":"http"},"periodSeconds":10},"name":"podinfo","ports":[{"containerPort":9898,"name":"http","protocol":"TCP"}],"readinessProbe":{"httpGet":{"path":"/readyz","port":"http"},"periodSeconds":5},"resources":{"limits":{"memory":"128Mi"},"requests":{"cpu":"10m","memory":"32Mi"}},"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsGroup":101,"runAsNonRoot":true,"runAsUser":100},"volumeMounts":[{"mountPath":"/data","name":"data"}]}],"initContainers":[{"command":["sh","-c","chown 100:101 /data \u0026\u0026 chmod 0750 /data \u0026\u0026 ls -ldn /data"],"image":"busybox:1.37.0","name":"fix-data-permissions","securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"add":["CHOWN","FOWNER"],"drop":["ALL"]},"runAsNonRoot":false,"runAsUser":0},"volumeMounts":[{"mountPath":"/data","name":"data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"podinfo-data"}}]}}}}
   creationTimestamp: "2026-11-20T11:28:22Z"
-  generation: 1
+  generation: 2
   labels:
     app.kubernetes.io/name: podinfo
   name: podinfo
@@ -34,7 +34,7 @@
         - --level=info
         command:
         - ./podinfo
-        image: stefanprodan/podinfo:6.14.1
+        image: stefanprodan/podinfo:6.17.0
         imagePullPolicy: IfNotPresent
         livenessProbe:
           failureThreshold: 3
[exit code: 1]

### 2026-11-20T12:29:59+01:00  (host: jozsef-nagy-nb02)
$ kubectl apply -k deployment/ && kubectl -n mst rollout status deploy/podinfo --timeout=180s
namespace/mst unchanged
service/podinfo unchanged
persistentvolumeclaim/podinfo-data unchanged
deployment.apps/podinfo configured
Waiting for deployment "podinfo" rollout to finish: 0 out of 1 new replicas have been updated...
Waiting for deployment "podinfo" rollout to finish: 0 out of 1 new replicas have been updated...
Waiting for deployment "podinfo" rollout to finish: 0 out of 1 new replicas have been updated...
Waiting for deployment "podinfo" rollout to finish: 0 of 1 updated replicas are available...
deployment "podinfo" successfully rolled out
[exit code: 0]

### 2026-11-20T12:30:38+01:00  (host: jozsef-nagy-nb02)
$ curl -sS http://127.0.0.1:9898/version; kubectl -n mst get pod -l app.kubernetes.io/name=podinfo -o jsonpath="{.items[0].status.containerStatuses[0].image}{\"\\n\"}{.items[0].status.containerStatuses[0].imageID}{\"\\n\"}"; curl -sS http://127.0.0.1:9898/store/$HASH | cmp - testdata/record.txt && echo MATCH
{
  "commit": "fd3a834ed8d14b80ea334cf8a2fddd4597924da6",
  "version": "6.17.0"
}docker.io/stefanprodan/podinfo:6.17.0
docker.io/stefanprodan/podinfo@sha256:fa2f27c1a8561097e5144bfc0853eba6054d743b68b03de4cad4675616ddefb0
MATCH
[exit code: 0]

### 2026-11-20T12:30:46+01:00  (host: jozsef-nagy-nb02)
$ kubectl apply -k deployment/ && kubectl diff -k deployment/ && echo "NINCS ELTERES"; git diff --stat deployment/
namespace/mst unchanged
service/podinfo unchanged
persistentvolumeclaim/podinfo-data unchanged
deployment.apps/podinfo unchanged
NINCS ELTERES
[exit code: 0]

### 2026-11-20T12:31:10+01:00  (host: jozsef-nagy-nb02)
$ kind delete cluster --name mst2 && kubectl config use-context kind-mst && kubectl config current-context && kind get clusters && kubectl -n mst get pods,pvc
Deleting cluster "mst2" ...
Deleted nodes: ["mst2-control-plane"]
Switched to context "kind-mst".
kind-mst
mst
NAME                           READY   STATUS    RESTARTS   AGE
pod/podinfo-6c784dc597-74dvc   1/1     Running   0          29m

NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/podinfo-data   Bound    pvc-344730ef-eaeb-4a80-a163-74d1bd41256e   1Gi        RWO            standard       <unset>                 72m
[exit code: 0]

### 2026-11-20T12:31:18+01:00  (host: jozsef-nagy-nb02)
$ curl -sS http://127.0.0.1:9898/store/$(cat evidence/T03-hash.txt) | cmp - evidence/T03-expected-record.txt && echo "MATCH (eredeti mst cluster)"
curl: (7) Failed to connect to 127.0.0.1 port 9898 after 0 ms: Could not connect to server
cmp: EOF on ‘-’ which is empty
[exit code: 1]

### 2026-11-20T12:31:35+01:00  (host: jozsef-nagy-nb02)
$ curl -sS http://127.0.0.1:9898/store/$(cat evidence/T03-hash.txt) | cmp - evidence/T03-expected-record.txt && echo "MATCH (eredeti mst cluster)"
curl: (7) Failed to connect to 127.0.0.1 port 9898 after 0 ms: Could not connect to server
cmp: EOF on ‘-’ which is empty
[exit code: 1]

### 2026-11-20T12:34:33+01:00  (host: jozsef-nagy-nb02)
$ kubectl config current-context; curl -sS http://127.0.0.1:9898/version; curl -sS http://127.0.0.1:9898/store/$(cat evidence/T03-hash.txt) | cmp - evidence/T03-expected-record.txt && echo "MATCH (eredeti mst cluster)"
kind-mst
{
  "commit": "fd3a834ed8d14b80ea334cf8a2fddd4597924da6",
  "version": "6.17.0"
}MATCH (eredeti mst cluster)
[exit code: 0]


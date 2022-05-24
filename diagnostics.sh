#!/bin/zsh

# Скрипт по сбору диагностики с кластера k8s. На выходе имеем zip-архив k8s.zip.
# Файлы: log.txt, events.txt, describe_nodes.txt, pvc_pv.txt, operations.txt

FILE_LOG=log.txt
FILE_EVENTS=events.txt
FILE_NODES=describe_nodes.txt
FILE_PVC_PV=pvc.yaml
FILE_OPERATIONS=operations.txt

files=($FILE_LOG $FILE_EVENTS $FILE_NODES $FILE_PVC_PV $FILE_OPERATIONS)

for file in $files
do
touch $file
done

# Pods 
date >> $FILE_LOG
echo "-----------------------------------" &>> $FILE_LOG
echo "Введите cluster-id k8s кластера: "
read cluster_id
echo "Описание кластера: " &>> $FILE_LOG
yc managed-kubernetes cluster get --id=$cluster_id &>> $FILE_LOG
echo "Подключаемся к кластеру k8s: " &>> $FILE_LOG
yc managed-kubernetes cluster get-credentials --id $cluster_id --external --force &>> $FILE_LOG
echo "Введите тип проблемного ресурса (пример: deployment, daemonset, statefulset и так далее): "
read resource_type
echo "Введите имя ресурса (имя deployment-a, daemonset-a, statefulset-a и так далее): "
read resource_name
echo "Введите имя namespace-a, где находится проблемный ресурс: "
read namespace
echo "-----------------------------------" &>> $FILE_LOG
kubectl get $resource_type $resource_name -n $namespace &>> $FILE_LOG
echo "-----------------------------------" &>> $FILE_LOG
kubectl get pods -n $namespace | grep $resource_name | awk '{print $1}' &> list.txt
while read pod
do
echo "-----------------------------------" &>> $FILE_LOG
echo "Лог пода: "  &>> $FILE_LOG
kubectl logs -n $namespace $pod &>> $FILE_LOG
echo "Дескрайб пода: " &>> $FILE_LOG
kubectl describe pods -n $namespace $pod &>> $FILE_LOG
done < list.txt
rm list.txt

# Events
date >> $FILE_EVENTS
echo "Ивенты с сортировкой по timestamp-ам: " &>> $FILE_EVENTS
kubectl get events --all-namespaces  --sort-by='.metadata.creationTimestamp' &>> $FILE_EVENTS

# Nodes
date >> $FILE_NODES
echo "Листинг нод-групп: " &>> $FILE_NODES
yc managed-kubernetes cluster list-node-groups --id=$cluster_id &>> $FILE_NODES
echo "Листинг нод: " &>> $FILE_NODES
yc managed-kubernetes cluster list-nodes --id=$cluster_id &>> $FILE_NODES
echo "Список нод в кластере: " &>> $FILE_NODES
kubectl get nodes -o wide &>> $FILE_NODES
echo "Дескрайб нод: " &>> $FILE_NODES
kubectl describe nodes $(kubectl get pods -o wide | awk '{print $7}') &>> $FILE_NODES

# PVC/PV/StorageClass
echo "Есть проблема с PV/PVC? (если да, введи true; если нет, введи false)"
read isProblem 
if $isProblem -eq "true"
then
echo "Введите имя pvc: "
read pvc_name
echo "Введите имя namespace-a pvc: "
read pvc_namespace
date >> $FILE_PVC_PV
echo "-----------------------------------" &>> $FILE_PVC_PV
kubectl get pvc $pvc_name -n $pvc_namespace &>> $FILE_PVC_PV
echo "-----------------------------------" &>> $FILE_PVC_PV
kubectl get pvc $pvc_name -n $pvc_namespace -o yaml &>> $FILE_PVC_PV
else 
echo "У тебя нет проблем с PV/PVC, круто!"
rm $FILE_PVC_PV
fi

# Operations
date >> $FILE_OPERATIONS
echo "Листинг операций в кластера: " &>> $FILE_OPERATIONS
yc managed-kubernetes cluster list-operations --id=$cluster_id &>> $FILE_OPERATIONS

# Creating zip-archive and deleting old files
for file in $files
do
zip k8s.zip $file
rm $file
done

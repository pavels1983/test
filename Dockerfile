FROM centos:7
MAINTAINER savchenkopa
# GP binary installer: https://network.pivotal.io/products/pivotal-gpdb#/releases/118471/file_groups/1013

ENV install_path /usr/local/greenplum-db-5.9.0
ENV password welcome1

# Move GP distribution archive to /tmp
COPY * /tmp/

RUN /usr/sbin/groupadd gpadmin && \
    /usr/sbin/useradd gpadmin -g gpadmin && \
    echo "${password}" | passwd --stdin gpadmin && \
    echo "root:${password}" | chpasswd && \
    yum install -y unzip which tar more util-linux-ng passwd openssh-clients openssh-server ed m4 net-tools iproute less; yum clean all

# configure sshd
ENV NOTVISIBLE "in users profile"
RUN mkdir /var/run/sshd && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i -r 's/^.*StrictHostKeyChecking\s+\w+/StrictHostKeyChecking no/' /etc/ssh/ssh_config && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd && \
    echo "export VISIBLE=now" >> /etc/profile && \
    ssh-keygen -A && \
    echo -e '#!/bin/bash\n/usr/sbin/sshd -D &' > /var/run/sshd/sshd_start.sh && \
    chmod u+x /var/run/sshd/sshd_start.sh

RUN /var/run/sshd/sshd_start.sh && \
    su gpadmin && \
    su gpadmin -l -c "ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P \"\"" && \
    su gpadmin -l -c "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys" && \
    su gpadmin -l -c "chmod 600 ~/.ssh/authorized_keys" && \
    su gpadmin -l -c "ssh-keyscan -H localhost 2>/dev/null | grep rsa | awk '{print \"localhost \" \$2 \" \" \$3 }' >> ~/.ssh/known_hosts" && \
    echo "RemoveIPC=no" >> /etc/systemd/logind.conf && \
    export distr_name=`ls /tmp | grep greenplum-db` && \
    export distr_name="${distr_name%%.???}" && \
    unzip /tmp/${distr_name}.zip -d /tmp/ && \
    rm /tmp/${distr_name}.zip && \
    sed -i s/"more << EOF"/"cat << EOF"/g /tmp/${distr_name}.bin && \
    echo -e "yes\n\nyes\nyes\n" | /tmp/${distr_name}.bin && \
    rm -Rf /tmp/${distr_name}* && \
    chown -R gpadmin ${install_path}* && \
    cat /tmp/sysctl.conf.add >> /etc/sysctl.conf && \
    cat /tmp/limits.conf.add >> /etc/security/limits.conf && \
    rm -f /tmp/*.add && \
    echo "localhost" > ${install_path}/gp_hosts_list && \
    mkdir -p /gpdata/master /gpdata/segments && \
    chown -R gpadmin: /gpdata && \
    chown gpadmin: /tmp/gpinit_conf_singlenode && \
    su gpadmin -l -c "source ${install_path}/greenplum_path.sh;gpssh-exkeys -f ${install_path}/gp_hosts_list" && \
    su gpadmin -l -c "source ${install_path}/greenplum_path.sh;${install_path}/bin/gpinitsystem -a -c /tmp/gpinit_conf_singlenode -h ${install_path}/gp_hosts_list";\
    su gpadmin -l -c "echo -e 'source ${install_path}/greenplum_path.sh' >> ~/.bashrc" && \
    su gpadmin -l -c "echo -e 'export MASTER_DATA_DIRECTORY=/gpdata/master/gpseg-1' >> ~/.bashrc" && \
    su gpadmin -l -c "echo -e 'export LD_PRELOAD=/lib64/libz.so.1 ps' >> ~/.bashrc" && \
    su gpadmin -l -c "source ~/.bashrc;psql -d template1 -c \"alter user gpadmin password '${password}'\"" && \
    su gpadmin -l -c "${install_path}/bin/createdb gpadmin; exit 0" && \
    su gpadmin -l -c "echo \"host all all 0.0.0.0/0 md5\" >> /gpdata/master/gpseg-1/pg_hba.conf" && \
    hostname > /tmp/gpinitsystem_hostname && \
    echo -e "\nBUILD DONE!"

EXPOSE 5432 22

VOLUME /gpdata

CMD echo "127.0.0.1 $(cat /tmp/gpinitsystem_hostname)" >> /etc/hosts && \
    /var/run/sshd/sshd_start.sh && \
    su gpadmin -l -c ". ~/.bashrc; gpstart -a" && \
    /bin/bash

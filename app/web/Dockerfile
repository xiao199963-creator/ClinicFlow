FROM nginx:1.28-alpine
ENV PORT=8080 LOCAL_STAFF_ACCESS=0 \
    NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1 NGINX_ENVSUBST_OUTPUT_DIR=/tmp
COPY nginx.conf.template /etc/nginx/templates/nginx.conf.template
COPY index.html schedule.html /usr/share/nginx/html/
USER 10001:10001
VOLUME /tmp
EXPOSE 8080
CMD ["nginx", "-c", "/tmp/nginx.conf", "-g", "daemon off;"]

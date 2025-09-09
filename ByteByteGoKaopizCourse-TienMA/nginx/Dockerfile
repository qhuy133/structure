FROM nginx:alpine

# Copy nginx configuration
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Copy frontend static files
COPY frontend/ /usr/share/nginx/html/

# Create log directory
RUN mkdir -p /var/log/nginx

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"] 
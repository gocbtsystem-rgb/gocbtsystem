FROM alpine:latest

WORKDIR /app

# Install tzdata (WIB/Jakarta timezone) dan sertifikat SSL
RUN apk add --no-cache tzdata ca-certificates
ENV TZ=Asia/Jakarta

# Copy file binary Linux
COPY gocbt_linux /app/gocbt
COPY gocbt-install /app/gocbt-install

# Beri permission eksekusi
RUN chmod +x /app/gocbt /app/gocbt-install

# Folder uploads
RUN mkdir -p /app/uploads

EXPOSE 8080

CMD ["/app/gocbt"]

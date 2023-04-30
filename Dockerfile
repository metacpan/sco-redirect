FROM metacpan/metacpan-base:latest

WORKDIR /app
COPY . .

RUN cpm install -g
EXPOSE 5005
CMD [ "plackup", "-p", "5005", "app.psgi" ]

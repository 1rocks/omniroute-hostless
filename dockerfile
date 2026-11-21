FROM node:22-slim

RUN apt-get update && apt-get install -y git sqlite3 python3 make g++ && rm -rf /var/lib/apt/lists/*
RUN npm install -g omniroute && which omniroute && omniroute --version

COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

ENV DATA_DIR=/tmp/omniroute-data
ENV HOST=0.0.0.0
EXPOSE 20128

CMD ["/bin/sh", "/start.sh"]

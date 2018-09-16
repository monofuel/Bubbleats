FROM alpine

# install latest nim from source
RUN apk update
RUN apk add git
RUN apk add build-base
WORKDIR /opt
RUN git clone https://github.com/nim-lang/Nim.git --depth 1
WORKDIR /opt/Nim
RUN sh build_all.sh
RUN ./bin/nim c koch
RUN ./koch boot -d:release
RUN ./koch tools
ENV PATH="/opt/Nim/bin:${PATH}"

# setup bubbleats
RUN mkdir /bubbleats
WORKDIR /bubbleats

# install nimble dependencies
# doing this early to prevent re-fetching on source changes
ADD ./Bubbleats.nimble /bubbleats/
RUN nimble check
RUN nimble install -d -y

# copy project into container
COPY . /bubbleats
RUN nimble build

CMD echo TODO run tests
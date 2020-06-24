FROM ubuntu

# Update the apt repository
RUN apt update

# Install dependencies
RUN apt install -y zsh
RUN apt install -y git
RUN apt install -y sudo
RUN apt install -y ruby
RUN apt install -y curl
RUN apt install -y vim

# take an SSH key as a build argument
ARG PRIVATE_KEY
ARG PUBLIC_KEY

# Create a test user
RUN useradd -ms /bin/bash user && \
        echo "user ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/user && \
        chmod 0440 /etc/sudoers.d/user

USER user:user

WORKDIR /home/user
RUN mkdir -p .ssh
RUN echo "$PRIVATE_KEY" > .ssh/id_rsa
RUN echo "$PUBLIC_KEY" > .ssh/id_rsa.pub
RUN chmod 600 .ssh/id_rsa
RUN chmod 600 .ssh/id_rsa.pub
RUN ssh-keyscan github.com >> .ssh/known_hosts

RUN mkdir -p code
# WORKDIR /home/user/code
# RUN git clone git@github.com:nicknisi/dotfiles.git

# WORKDIR /home/user/code/dotfiles

CMD ["/bin/bash"]

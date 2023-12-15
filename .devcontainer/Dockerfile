# Use the specified image
FROM registry.opensuse.org/opensuse/tumbleweed:latest

ARG USERNAME=node
ARG USER_UID=1000
ARG USER_GID=$USER_UID

#RUN useradd podman; \
#echo podman:10000:5000 > /etc/subuid; \
#echo podman:10000:5000 > /etc/subgid;

# Create the user
#RUN groupadd --gid $USER_GID $USERNAME
#RUN useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
#    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
#    && chmod 0440 /etc/sudoers.d/$USERNAME

# Copy the script into the image
COPY install-dependencies.sh /tmp/install-dependencies.sh

# Run the script
RUN /tmp/install-dependencies.sh

# Set the default user
#USER $USERNAME

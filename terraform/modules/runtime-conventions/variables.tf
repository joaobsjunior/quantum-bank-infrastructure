variable "project_name" {
  description = "Project identifier used in cloud resource names."
  type        = string
  default     = "quantum-bank"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "container_images" {
  description = "Container images for the Quantum Bank runtime services."
  type = object({
    backend           = string
    gateway_bootstrap = string
    gateway_banking   = string
    # Post-quantum TLS terminator (HAProxy + OpenSSL 3.5) that owns the public
    # socket of every internet-facing gateway container.
    gateway_tls = string
  })
}

variable "container_ports" {
  description = "Container ports for the Quantum Bank runtime services."
  type = object({
    backend           = number
    gateway_bootstrap = number
    gateway_banking   = number
  })
  default = {
    backend           = 8080
    gateway_bootstrap = 8080
    gateway_banking   = 8443
  }
}

variable "common_tags" {
  description = "Tags or labels common to every cloud path."
  type        = map(string)
  default     = {}
}

variable "pqc_transport" {
  description = "TLS policy every network hop must satisfy (documentation and sidecar configuration). Strict hops use the post-quantum values only; app-facing listeners additionally serve the compatibility chain and accept the compatibility group/schemes for peers whose TLS stack cannot verify ML-DSA yet."
  type = object({
    protocol                 = string
    key_exchange             = string
    signature_schemes        = list(string)
    ca_algorithm             = string
    leaf_algorithm           = string
    compat_key_exchange      = list(string)
    compat_signature_schemes = list(string)
    compat_ca_algorithm      = string
    compat_leaf_algorithm    = string
  })
  default = {
    protocol                 = "TLSv1.3"
    key_exchange             = "X25519MLKEM768"
    signature_schemes        = ["mldsa65", "mldsa87"]
    ca_algorithm             = "ML-DSA-87"
    leaf_algorithm           = "ML-DSA-65"
    compat_key_exchange      = ["X25519MLKEM768", "X25519"]
    compat_signature_schemes = ["mldsa65", "mldsa87", "ecdsa_secp256r1_sha256", "ecdsa_secp384r1_sha384"]
    compat_ca_algorithm      = "ECDSA-P384"
    compat_leaf_algorithm    = "ECDSA-P256"
  }
}

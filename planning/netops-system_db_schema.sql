-- ==========================================
-- TRIGGER FUNCTION FOR AUTOMATIC updated_at
-- ==========================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 1. USERS (Pooled from Org Microsoft Account)
-- ==========================================
CREATE TABLE "user" (
    user_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    department VARCHAR(150),
    job_title VARCHAR(150)
);

-- ==========================================
-- 2. REGIONS & PoPs
-- ==========================================
CREATE TABLE region (
    region_id SERIAL PRIMARY KEY,
    region_name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pop (
    pop_id SERIAL PRIMARY KEY,
    region_id INT NOT NULL,
    name VARCHAR(150) NOT NULL,
    pop_address TEXT,
    pop_coordinates VARCHAR(100),
    tier VARCHAR(50),
    contact_info TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pop_region FOREIGN KEY (region_id)
        REFERENCES region(region_id) ON DELETE RESTRICT
);

-- ==========================================
-- 3. CUSTOMERS & SERVICE TYPES
-- ==========================================
CREATE TABLE customer (
    customer_id SERIAL PRIMARY KEY,
    customer_site_id VARCHAR(100),
    region INT,
    customer_description TEXT,
    customer_address TEXT,
    account_status VARCHAR(50) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_customer_region FOREIGN KEY (region)
        REFERENCES region(region_id) ON DELETE SET NULL
);

CREATE TABLE service_type (
    service_type_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    sla_level VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 4. CARRIER PARTNERS
-- ==========================================
CREATE TABLE carrier_partner (
    partner_id SERIAL PRIMARY KEY,
    partner_name VARCHAR(150) NOT NULL UNIQUE,
    contact_info TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 5. NETWORK DEVICES, INTERFACES & NNI
-- ==========================================
CREATE TABLE network_device (
    network_device_id SERIAL PRIMARY KEY,
    hostname VARCHAR(255) NOT NULL UNIQUE,
    mgmt_ip_address VARCHAR(45),
    region_id INT NOT NULL,
    pop_id INT,
    device_type VARCHAR(100) NOT NULL,
    vendor_oem VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_device_region FOREIGN KEY (region_id)
        REFERENCES region(region_id) ON DELETE RESTRICT,
    CONSTRAINT fk_device_pop FOREIGN KEY (pop_id)
        REFERENCES pop(pop_id) ON DELETE SET NULL
);

CREATE TABLE network_device_interface (
    interface_id SERIAL PRIMARY KEY,
    network_device_id INT NOT NULL,
    interface_name VARCHAR(100) NOT NULL,
    description TEXT,
    speed VARCHAR(50),
    status VARCHAR(50) NOT NULL DEFAULT 'Up',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_interface_device FOREIGN KEY (network_device_id)
        REFERENCES network_device(network_device_id) ON DELETE CASCADE,
    CONSTRAINT uk_device_interface UNIQUE (network_device_id, interface_name)
);

CREATE TABLE nni_interface_partner (
    nni_interface_id SERIAL PRIMARY KEY,
    network_device_interface_id INT NOT NULL,
    carrier_partner_id INT NOT NULL,
    nni_region_id INT NOT NULL,
    bandwidth VARCHAR(50) NOT NULL,
    provisioned_date DATE DEFAULT CURRENT_DATE,
    status VARCHAR(50) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_nni_interface FOREIGN KEY (network_device_interface_id)
        REFERENCES network_device_interface(interface_id) ON DELETE RESTRICT,
    CONSTRAINT fk_nni_partner FOREIGN KEY (carrier_partner_id)
        REFERENCES carrier_partner(partner_id) ON DELETE RESTRICT,
    CONSTRAINT fk_nni_region FOREIGN KEY (nni_region_id)
        REFERENCES region(region_id) ON DELETE RESTRICT
);

CREATE TABLE network_device_configs (
    config_id SERIAL PRIMARY KEY,
    network_device_id INT NOT NULL,
    config_type VARCHAR(100) NOT NULL,
    config_content TEXT NOT NULL,
    version VARCHAR(50) NOT NULL,
    applied_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_config_device FOREIGN KEY (network_device_id)
        REFERENCES network_device(network_device_id) ON DELETE CASCADE
);

-- ==========================================
-- 6. SERVICE REQUESTS & PROVISIONING TASKS
-- ==========================================
CREATE TABLE service_request (
    service_request_id SERIAL PRIMARY KEY,
    requested_by_user_id INT NOT NULL,
    customer_id INT NOT NULL,
    region_id INT NOT NULL,
    pop_id INT,
    service_type_id INT NOT NULL,
    carrier_partner_id INT,
    capacity VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Pending',
    activation_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_req_user FOREIGN KEY (requested_by_user_id)
        REFERENCES "user"(user_id) ON DELETE RESTRICT,
    CONSTRAINT fk_req_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id) ON DELETE RESTRICT,
    CONSTRAINT fk_req_region FOREIGN KEY (region_id)
        REFERENCES region(region_id) ON DELETE RESTRICT,
    CONSTRAINT fk_req_pop FOREIGN KEY (pop_id)
        REFERENCES pop(pop_id) ON DELETE SET NULL,
    CONSTRAINT fk_req_service_type FOREIGN KEY (service_type_id)
        REFERENCES service_type(service_type_id) ON DELETE RESTRICT,
    CONSTRAINT fk_req_carrier_partner FOREIGN KEY (carrier_partner_id)
        REFERENCES carrier_partner(partner_id) ON DELETE SET NULL
);

CREATE TABLE provisioning_task (
    task_id SERIAL PRIMARY KEY,
    service_request_id INT NOT NULL,
    task_type VARCHAR(150) NOT NULL,
    assigned_to INT, -- References Core IP engineer (user_id) who picks up the task
    status VARCHAR(50) NOT NULL DEFAULT 'Queued',
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_task_service_request FOREIGN KEY (service_request_id)
        REFERENCES service_request(service_request_id) ON DELETE CASCADE,
    CONSTRAINT fk_task_assigned_to FOREIGN KEY (assigned_to)
        REFERENCES "user"(user_id) ON DELETE SET NULL
);

-- ==========================================
-- 7. SUBNETS & SERVICE ACTIVATION
-- ==========================================
CREATE TABLE public_ip_subnets (
    public_ip_subnet_id SERIAL PRIMARY KEY,
    nni_id INT,
    customer_id INT,
    cidr_block VARCHAR(50) NOT NULL,
    vlan_id INT,
    usage_type VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'Assigned',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pub_subnet_nni FOREIGN KEY (nni_id)
        REFERENCES nni_interface_partner(nni_interface_id) ON DELETE SET NULL,
    CONSTRAINT fk_pub_subnet_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id) ON DELETE SET NULL
);

CREATE TABLE private_ip_subnets (
    private_ip_subnet_id SERIAL PRIMARY KEY,
    nni_id INT,
    customer_id INT,
    cidr_block VARCHAR(50) NOT NULL,
    vlan_id INT,
    usage_type VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'Assigned',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_priv_subnet_nni FOREIGN KEY (nni_id)
        REFERENCES nni_interface_partner(nni_interface_id) ON DELETE SET NULL,
    CONSTRAINT fk_priv_subnet_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id) ON DELETE SET NULL
);

CREATE TABLE service_activation (
    service_activation_id SERIAL PRIMARY KEY,
    service_request_id INT NOT NULL,
    customer_id INT NOT NULL,
    service_type_id INT NOT NULL,
    private_ip_subnet_id INT,
    public_ip_subnet_id INT,
    network_device_config INT,
    provisioned_by INT,        -- References Core IP engineer (user_id) who provisioned the service
    approved_by_user_id INT,   -- References Core IP manager (user_id) who approved the config
    status VARCHAR(50) NOT NULL DEFAULT 'Pending',
    activation_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_act_request FOREIGN KEY (service_request_id)
        REFERENCES service_request(service_request_id) ON DELETE RESTRICT,
    CONSTRAINT fk_act_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id) ON DELETE RESTRICT,
    CONSTRAINT fk_act_service_type FOREIGN KEY (service_type_id)
        REFERENCES service_type(service_type_id) ON DELETE RESTRICT,
    CONSTRAINT fk_act_priv_subnet FOREIGN KEY (private_ip_subnet_id)
        REFERENCES private_ip_subnets(private_ip_subnet_id) ON DELETE SET NULL,
    CONSTRAINT fk_act_pub_subnet FOREIGN KEY (public_ip_subnet_id)
        REFERENCES public_ip_subnets(public_ip_subnet_id) ON DELETE SET NULL,
    CONSTRAINT fk_act_device_config FOREIGN KEY (network_device_config)
        REFERENCES network_device_configs(config_id) ON DELETE SET NULL,
    CONSTRAINT fk_act_provisioned_by FOREIGN KEY (provisioned_by)
        REFERENCES "user"(user_id) ON DELETE SET NULL,
    CONSTRAINT fk_act_approved_by FOREIGN KEY (approved_by_user_id)
        REFERENCES "user"(user_id) ON DELETE SET NULL
);

-- ==========================================
-- 8. UPDATED_AT TRIGGERS & INDEXES
-- ==========================================
CREATE TRIGGER trg_region_updated_at BEFORE UPDATE ON region
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_pop_updated_at BEFORE UPDATE ON pop
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_customer_updated_at BEFORE UPDATE ON customer
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_service_type_updated_at BEFORE UPDATE ON service_type
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_carrier_partner_updated_at BEFORE UPDATE ON carrier_partner
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_network_device_updated_at BEFORE UPDATE ON network_device
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_network_device_interface_updated_at BEFORE UPDATE ON network_device_interface
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_nni_interface_partner_updated_at BEFORE UPDATE ON nni_interface_partner
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_service_request_updated_at BEFORE UPDATE ON service_request
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_provisioning_task_updated_at BEFORE UPDATE ON provisioning_task
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_public_ip_subnets_updated_at BEFORE UPDATE ON public_ip_subnets
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_private_ip_subnets_updated_at BEFORE UPDATE ON private_ip_subnets
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_service_activation_updated_at BEFORE UPDATE ON service_activation
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_pop_region ON pop(region_id);
CREATE INDEX idx_device_region ON network_device(region_id);
CREATE INDEX idx_device_pop ON network_device(pop_id);
CREATE INDEX idx_interface_device ON network_device_interface(network_device_id);
CREATE INDEX idx_nni_interface ON nni_interface_partner(network_device_interface_id);
CREATE INDEX idx_nni_partner ON nni_interface_partner(carrier_partner_id);
CREATE INDEX idx_nni_region ON nni_interface_partner(nni_region_id);
CREATE INDEX idx_service_request_user ON service_request(requested_by_user_id);
CREATE INDEX idx_service_request_customer ON service_request(customer_id);
CREATE INDEX idx_service_request_status ON service_request(status);
CREATE INDEX idx_task_request ON provisioning_task(service_request_id);
CREATE INDEX idx_task_assigned_to ON provisioning_task(assigned_to);
CREATE INDEX idx_pub_subnet_cidr ON public_ip_subnets(cidr_block);
CREATE INDEX idx_priv_subnet_cidr ON private_ip_subnets(cidr_block);
CREATE INDEX idx_activation_request ON service_activation(service_request_id);
CREATE INDEX idx_activation_provisioned_by ON service_activation(provisioned_by);
CREATE INDEX idx_activation_approved_by ON service_activation(approved_by_user_id);
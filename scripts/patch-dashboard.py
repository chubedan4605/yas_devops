import os

f = 'observability_dashboard.yaml'
if os.path.exists(f):
    content = open(f, 'r', encoding='utf-8').read()
    repls = {
        # HTTP metrics
        'http_server_request_duration_seconds_count': 'http_server_requests_seconds_count',
        'http_server_request_duration_seconds_sum': 'http_server_requests_seconds_sum',
        'http_response_status_code': 'status',
        'http_request_method': 'method',
        'http_route': 'uri',
        
        # JVM / Thread / GC / CPU metrics
        'jvm_class_count': 'jvm_classes_loaded_classes',
        'jvm_class_loaded_total': 'jvm_classes_loaded_classes',
        'jvm_memory_limit_bytes': 'jvm_memory_max_bytes',
        'jvm_memory_used_after_last_gc_bytes': 'jvm_memory_used_bytes',
        'jvm_cpu_recent_utilization_ratio': 'process_cpu_usage',
        'jvm_gc_duration_seconds_sum': 'jvm_gc_pause_seconds_sum',
        'jvm_thread_count': 'jvm_threads_live_threads',
        'jvm_cpu_count': 'system_cpu_count',
        'jvm_memory_used_bytes{service_name=\\\"$service\\\", id=~\\\"$jvm_buffer_pool\\\"}': 'jvm_buffer_memory_used_bytes{service_name=\\\"$service\\\", id=~\\\"$jvm_buffer_pool\\\"}',
        
        # Database Connection metrics
        'db_client_connections_max': 'hikaricp_connections_max',
        'db_client_connections_usage': 'hikaricp_connections_active'
    }
    for k, v in repls.items():
        content = content.replace(k, v)
    open(f, 'w', encoding='utf-8').write(content)
    print("Dashboard patched successfully with all Micrometer metrics (including system_cpu_count)!")
else:
    print("File not found!")

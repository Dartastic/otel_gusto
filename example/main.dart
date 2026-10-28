// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_gusto/otel_gusto.dart';

/// Traces Gusto calls with OpenTelemetry.
///
/// `otel_gusto` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Gusto call in
/// [tracedGusto]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'gusto-example');

  // Wraps a Gusto API call in a CLIENT span.
  final gustoId = await tracedGusto<String>(
    operation: 'employees.create',
    companyId: 'company_8f3a2c',
    apiVersion: '1',
    invoke: () async {
      // Make the Gusto call here, then report what it returned.
      const id = 'gusto_8f3a2c';
      return const GustoCallResult(
          value: id,
          result: GustoResult(
              itemCount: 3,
              payrollStatus: 'unprocessed',
              processingType: 'regular',
              payrollId: 'payroll_8f3a2c',
              employeeCount: 3,
              contractorCount: 3,
              amountTotalCents: 1999,
              processedAt: 'processed_date',
              requestId: 'request-id',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedGusto employees.create returned $gustoId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutGustoInstrumentationAsync.
  await runWithoutGustoInstrumentationAsync(
    () => tracedGusto<String>(
      operation: 'employees.create',
      companyId: 'company_8f3a2c',
      apiVersion: '1',
      invoke: () async {
        const id = 'gusto_8f3a2c';
        return const GustoCallResult(
            value: id,
            result: GustoResult(
                itemCount: 3,
                payrollStatus: 'unprocessed',
                processingType: 'regular',
                payrollId: 'payroll_8f3a2c',
                employeeCount: 3,
                contractorCount: 3,
                amountTotalCents: 1999,
                processedAt: 'processed_date',
                requestId: 'request-id',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}

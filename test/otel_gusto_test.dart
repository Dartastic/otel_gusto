// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_gusto/otel_gusto.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_gusto-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('payrolls.submit records status + processing_type + amount', () async {
    await tracedGusto<String>(
      operation: 'payrolls.submit',
      companyId: 'co-1',
      apiVersion: '2024-04-01',
      invoke: () async => const GustoCallResult(
        value: 'ok',
        result: GustoResult(
          payrollId: 'pr-1',
          payrollStatus: 'processed',
          processingType: 'regular',
          employeeCount: 12,
          contractorCount: 3,
          amountTotalCents: 4250000,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('gusto payrolls.submit')!);
    expect(a['gusto.company.id'], 'co-1');
    expect(a['gusto.payroll.status'], 'processed');
    expect(a['gusto.payroll.processing_type'], 'regular');
    expect(a['gusto.employee_count'], 12);
    expect(a['gusto.amount.total.minor'], 4250000);
  });

  test('cancelled payroll sets span error', () async {
    await tracedGusto<String>(
      operation: 'payrolls.cancel',
      invoke: () async => const GustoCallResult(
        value: 'ok',
        result: GustoResult(payrollStatus: 'cancelled'),
      ),
    );
    expect(
      spans.findSpanByName('gusto payrolls.cancel')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutGustoInstrumentationAsync(() async {
      await tracedGusto<String>(
        operation: 'employees.list',
        invoke: () async => const GustoCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('gusto '), isEmpty);
  });
}

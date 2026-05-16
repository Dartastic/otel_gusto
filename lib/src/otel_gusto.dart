// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_gusto_suppression.dart';

const _tracerName = 'dartastic_otel_libs_gusto';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class GustoResult {
  const GustoResult({
    this.itemCount,
    this.payrollStatus,
    this.processingType,
    this.payrollId,
    this.employeeCount,
    this.contractorCount,
    this.amountTotalCents,
    this.processedAt,
    this.requestId,
    this.statusCode,
  });

  /// `data.length`.
  final int? itemCount;

  /// `unprocessed` / `processed` / `paid` / `cancelled` /
  /// `processing`.
  final String? payrollStatus;

  /// `regular` / `off_cycle` / `dismissal` / `correction` — pricing
  /// differs.
  final String? processingType;

  /// Payroll UUID.
  final String? payrollId;

  /// Employees included in this payroll.
  final int? employeeCount;

  /// Contractors paid.
  final int? contractorCount;

  /// Total gross pay (cents, integer to avoid float drift).
  final int? amountTotalCents;

  /// `processed_date`.
  final String? processedAt;

  /// `X-Gusto-API-Version-Selected` request id (header is
  /// `request-id`).
  final String? requestId;

  final int? statusCode;
}

class GustoCallResult<T> {
  const GustoCallResult({required this.value, this.result});
  final T value;
  final GustoResult? result;
}

/// Wraps a Gusto API call in a CLIENT span. [operation] is one of
/// `companies.get`, `companies.list`, `employees.list`, `employees.get`,
/// `employees.create`, `employees.update`, `contractors.list`,
/// `payrolls.list`, `payrolls.get`, `payrolls.calculate`,
/// `payrolls.submit`, `payrolls.cancel`, `pay_periods.list`,
/// `pay_stubs.list`, `time_off_requests.list`, `benefits.list`,
/// `webhooks.create`.
Future<T> tracedGusto<T>({
  required String operation,
  required Future<GustoCallResult<T>> Function() invoke,
  String? companyId,
  String? apiVersion,
}) async {
  if (gustoInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'gusto',
    'rpc.method': operation,
    'gusto.operation': operation,
  };
  if (companyId != null) m['gusto.company.id'] = companyId;
  if (apiVersion != null) m['gusto.api_version'] = apiVersion;

  final span = _tracer().startSpan(
    'gusto $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTel.attributeInt(
          'gusto.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.payrollStatus != null) {
        extras.add(OTel.attributeString(
          'gusto.payroll.status',
          r.result!.payrollStatus!,
        ));
        if (r.result!.payrollStatus == 'cancelled') {
          span.setStatus(
            SpanStatusCode.Error,
            'Gusto payroll cancelled',
          );
        }
      }
      if (r.result!.processingType != null) {
        extras.add(OTel.attributeString(
          'gusto.payroll.processing_type',
          r.result!.processingType!,
        ));
      }
      if (r.result!.payrollId != null) {
        extras.add(OTel.attributeString(
          'gusto.payroll.id',
          r.result!.payrollId!,
        ));
      }
      if (r.result!.employeeCount != null) {
        extras.add(OTel.attributeInt(
          'gusto.employee_count',
          r.result!.employeeCount!,
        ));
      }
      if (r.result!.contractorCount != null) {
        extras.add(OTel.attributeInt(
          'gusto.contractor_count',
          r.result!.contractorCount!,
        ));
      }
      if (r.result!.amountTotalCents != null) {
        extras.add(OTel.attributeInt(
          'gusto.amount.total.minor',
          r.result!.amountTotalCents!,
        ));
      }
      if (r.result!.processedAt != null) {
        extras.add(OTel.attributeString(
          'gusto.processed_at',
          r.result!.processedAt!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'gusto.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Gusto HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

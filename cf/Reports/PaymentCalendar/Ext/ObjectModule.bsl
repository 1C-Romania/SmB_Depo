#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Procedure - "FillCheckProcessing" event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DelayedPaymentsPeriod.StartDate > WorkingDate Then
		ErrorText = NStr("en='Overdue payment period cannot be more than the current date. Report generation is canceled.';ru='Период просроченных платежей не может быть больше текущей даты. Формирование отчета отменено.'");
		CommonUseClientServer.MessageToUser(
			ErrorText,
			Undefined, // ObjectOrRef
			"DelayedPaymentsPeriod",
			"Report", // DataPath
			Cancel
		);
	EndIf;

	If FuturePaymentsPeriod.EndDate < WorkingDate Then
		ErrorText = NStr("en='Future payment period cannot be less than the current date. Report generation is canceled.';ru='Период будущих платежей не может быть меньше текущей даты. Формирование отчета отменено.'");
		CommonUseClientServer.MessageToUser(
			ErrorText,
			Undefined, // ObjectOrRef
			"FuturePaymentsPeriod",
			"Report", // DataPath
			Cancel
		);
	EndIf;
		
EndProcedure // FillCheckProcessing()

#EndIf
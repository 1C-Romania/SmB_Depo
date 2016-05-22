#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Procedure - "FillCheckProcessing" event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DelayedPaymentsPeriod.StartDate > WorkingDate Then
		ErrorText = NStr("en='Delayed payments period can not be more than the current date. Report generation is prohibited.'");
		CommonUseClientServer.MessageToUser(
			ErrorText,
			Undefined, // ObjectOrRef
			"DelayedPaymentsPeriod",
			"Report", // DataPath
			Cancel
		);
	EndIf;

	If FuturePaymentsPeriod.EndDate < WorkingDate Then
		ErrorText = NStr("en='Future payments period can not be less than the current date. Report generation is prohibited.'");
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
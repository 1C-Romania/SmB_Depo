#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If (NOT IsFolder) AND ValueIsFilled(StartDate)
		AND ValueIsFilled(EndDate) Then
		
		If StartDate > EndDate Then
			
			Message = New UserMessage;
			Message.Text = NStr("en='""Start date"" is greater than ""Ending date"" field value.';ru='Значение поля ""Дата начала"" больше значения поля ""Дата окончания""'");
			Message.Field = "Object.StartDate";
			Message.Message();
			
			Cancel = True;
			
		EndIf;
		
	EndIf;
	
	If (NOT IsFolder) AND (Ref = Catalogs.PlanningPeriods.Actual) Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "StartDate");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "EndDate");
		
	EndIf;
	
EndProcedure // FillCheckProcessing()

#EndRegion

#EndIf
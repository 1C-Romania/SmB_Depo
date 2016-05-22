#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		
		// Delete duplicates and empty strings.
		SelectedProperties = New Map;
		PropertiesToDelete = New Array;
		
		// Additional attributes.
		For Each AdditionalAttribute IN AdditionalAttributes Do
			
			If AdditionalAttribute.Property.IsEmpty()
			 OR SelectedProperties.Get(AdditionalAttribute.Property) <> Undefined Then
				
				PropertiesToDelete.Add(AdditionalAttribute);
			Else
				SelectedProperties.Insert(AdditionalAttribute.Property, True);
			EndIf;
		EndDo;
		
		For Each PropertyToDelete IN PropertiesToDelete Do
			AdditionalAttributes.Delete(PropertyToDelete);
		EndDo;
		
		SelectedProperties.Clear();
		PropertiesToDelete.Clear();
		
		// Additional info.
		For Each AdditionalInf IN AdditionalInformation Do
			
			If AdditionalInf.Property.IsEmpty()
			 OR SelectedProperties.Get(AdditionalInf.Property) <> Undefined Then
				
				PropertiesToDelete.Add(AdditionalInf);
			Else
				SelectedProperties.Insert(AdditionalInf.Property, True);
			EndIf;
		EndDo;
		
		For Each PropertyToDelete IN PropertiesToDelete Do
			AdditionalInformation.Delete(PropertyToDelete);
		EndDo;
		
		// Calculation of number of properties not marked for deletion.
		CountAttributes = Format(AdditionalAttributes.FindRows(
			New Structure("DeletionMark", False)).Count(), "NG=");
		
		CountInformation   = Format(AdditionalInformation.FindRows(
			New Structure("DeletionMark", False)).Count(), "NG=");
	
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		// Update of upper group content for use
		// when setting the content of dynamic list fields and setup (selections, ...).
		If ValueIsFilled(Parent) Then
			PropertiesManagementService.CheckRefreshContentFoldersProperties(Parent);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// IN the event handler of the FillingProcessor document
// - the catalog is filled according to the counterparty
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		If FillingData.IsFolder Then
			Return;
		EndIf;
		
		Owner = FillingData.Ref;
		
	EndIf;
	
EndProcedure // FillingProcessor()

#EndRegion

#EndIf
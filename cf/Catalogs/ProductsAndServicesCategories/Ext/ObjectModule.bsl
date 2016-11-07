#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Cancel Then
		
		If Not ValueIsFilled(SetOfCharacteristicProperties) Then
			ObjectSet = Catalogs.AdditionalAttributesAndInformationSets.CreateItem();
		Else
			ObjectSet = SetOfCharacteristicProperties.GetObject();
			LockDataForEdit(ObjectSet.Ref);
		EndIf;

		ObjectSet.Description    = Description;
		ObjectSet.Parent        = Catalogs.AdditionalAttributesAndInformationSets.Catalog_ProductsAndServicesCharacteristics;
		ObjectSet.DeletionMark = DeletionMark;
		ObjectSet.Write();
		SetOfCharacteristicProperties = ObjectSet.Ref;
		
	EndIf;	
	
EndProcedure // BeforeWrite()

// Procedure - event handler  AtCopy.
//
Procedure OnCopy(CopiedObject)
	
	SetOfCharacteristicProperties = Undefined;
	
EndProcedure // OnCopy()

#EndRegion

#EndIf
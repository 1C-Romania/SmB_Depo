#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnCopy(CopiedObject)
	
	Title = "";
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If PropertiesManagementService.ValueTypeContainsPropertiesValues(ValueType) Then
		
		Query = New Query;
		Query.SetParameter("ValueOwner", Ref);
		Query.Text =
		"SELECT
		|	Properties.Ref AS Ref,
		|	Properties.ValueType AS ValueType
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS Properties
		|WHERE
		|	Properties.AdditionalValuesOwner = &ValueOwner";
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			NewValueType = Undefined;
			
			If ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
			   AND Not Selection.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
				
				NewValueType = New TypeDescription(
					Selection.ValueType,
					"CatalogRef.ObjectsPropertiesValues",
					"CatalogRef.ObjectsPropertiesValuesHierarchy");
				
			ElsIf ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValuesHierarchy"))
			        AND Not Selection.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValuesHierarchy")) Then
				
				NewValueType = New TypeDescription(
					Selection.ValueType,
					"CatalogRef.ObjectsPropertiesValuesHierarchy",
					"CatalogRef.ObjectsPropertiesValues");
				
			EndIf;
			
			If NewValueType <> Undefined Then
				CurrentObject = Selection.Ref.GetObject();
				CurrentObject.ValueType = NewValueType;
				CurrentObject.DataExchange.Load = True;
				CurrentObject.Write();
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Property", Ref);
	Query.Text =
	"SELECT
	|	PropertiesSets.Ref AS Ref
	|FROM
	|	Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS PropertiesSets
	|WHERE
	|	PropertiesSets.Property = &Property
	|
	|UNION
	|
	|SELECT
	|	PropertiesSets.Ref
	|FROM
	|	Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation AS PropertiesSets
	|WHERE
	|	PropertiesSets.Property = &Property";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		CurrentObject = Selection.Ref.GetObject();
		// Delete  additional attributes.
		IndexOf = CurrentObject.AdditionalAttributes.Count()-1;
		While IndexOf >= 0 Do
			If CurrentObject.AdditionalAttributes[IndexOf].Property = Ref Then
				CurrentObject.AdditionalAttributes.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		// Delete additional info.
		IndexOf = CurrentObject.AdditionalInformation.Count()-1;
		While IndexOf >= 0 Do
			If CurrentObject.AdditionalInformation[IndexOf].Property = Ref Then
				CurrentObject.AdditionalInformation.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		If CurrentObject.Modified() Then
			CurrentObject.DataExchange.Load = True;
			CurrentObject.Write();
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf

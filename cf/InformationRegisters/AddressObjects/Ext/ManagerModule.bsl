#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// It updates the RF territorial entities data in the address objects.
// Records are mapped based on the RFTerritorialEntityCode field.
//
Procedure UpdateRFTerritorialEntitiesContentByClassifier(InitialFillingAndDataUpdate = False) Export
	
	Classifier = RFTerritorialEntitiesClassifier();
	
	// Select the ones that are in the layout, but are not found in the register.
	Query = New Query("
		|SELECT
		|	Parameter.RFTerritorialEntityCode AS RFTerritorialEntityCode
		|INTO
		|	Classifier
		|FROM
		|	&Classifier AS Parameter
		|INDEX BY
		|	RFTerritorialEntityCode
		|;
		|
		|SELECT
		|	Classifier.RFTerritorialEntityCode AS RFTerritorialEntityCode
		|FROM
		|	Classifier AS Classifier
		|LEFT JOIN
		|	InformationRegister.AddressObjects AS AddressObjects
		|ON
		|	  AddressObjects.Level                    = 1
		|	AND AddressObjects.RFTerritorialEntityCode              = Classifier.RFTerritorialEntityCode
		|	AND AddressObjects.RegionCode                  = 0
		|	AND AddressObjects.RegionCode                  = 0
		|	AND AddressObjects.CityCode                  = 0
		|	AND AddressObjects.UrbanDistrictCode  = 0
		|	AND AddressObjects.SettlementCode       = 0
		|	AND AddressObjects.StreetCode                   = 0
		|	AND AddressObjects.AdditionalItemCode = 0
		|	AND AddressObjects.SubordinateItemCode    = 0
		|WHERE
		|	AddressObjects.ID IS NULL
		|");
	Query.SetParameter("Classifier", Classifier);
	NewRFTerritorialEntities = Query.Execute().Unload();
	
	// Rewrite only the missing ones.
	Set = InformationRegisters.AddressObjects.CreateRecordSet();
	Filter = Set.Filter.RFTerritorialEntityCode;
	
	For Each RFTerritorialEntity IN NewRFTerritorialEntities Do
		Filter.Set(RFTerritorialEntity.RFTerritorialEntityCode);
		Set.Clear();
		
		SourceData = Classifier.Find(RFTerritorialEntity.RFTerritorialEntityCode, "RFTerritorialEntityCode");
		
		NewRFTerritorialEntity = Set.Add();
		FillPropertyValues(NewRFTerritorialEntity, SourceData);
		NewRFTerritorialEntity.Level = 1;
		
		If InitialFillingAndDataUpdate Then
			InfobaseUpdate.WriteData(Set);
		Else
			Set.Write();
		EndIf;
	EndDo;
	
EndProcedure

// It returns information from the RF territorial entities classifier.
//
// Returns:
//     ValueTable - supplied data. Columns:
//       * RFTerritorialEntityCode  - Number  - territorial entity classifier code, for example, 77 for Moscow.
//       * Description   - String - Entity name by the classifier. For example, "Moscow".
//       * Abbreviation  - String - Entity name by the classifier. For example, "Region".
//       * PostalCode    - Number  - state index. If 0 - then it is undefined.
//       * Identifier    - UUID - FIAS identifier.
//
Function RFTerritorialEntitiesClassifier() Export
	
	Template = InformationRegisters.AddressObjects.GetTemplate("RFTerritorialEntitiesClassifier");
	
	Read = New XMLReader;
	Read.SetString(Template.GetText());
	Result = XDTOSerializer.ReadXML(Read);
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf
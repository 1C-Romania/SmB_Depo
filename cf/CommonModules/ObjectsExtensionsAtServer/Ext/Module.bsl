Procedure SetCatalogAttributeFromParent(AttributeName, CatalogObject,Parent = Undefined) Export 
	
	AttributesTypes = CatalogObject.Metadata().Attributes[AttributeName].Type.Types();
	If (AttributesTypes.Count() = 1 AND AttributesTypes[0] = Type("Boolean"))
		OR ValueIsNotFilled(CatalogObject[AttributeName]) Then
		If Parent = Undefined Then
			Parent = CatalogObject.Parent;
		EndIf;	
		CatalogObject[AttributeName] = Parent[AttributeName];
	EndIf;	
	
EndProcedure // ObjectsExtensionsAtServer.SetCatalogAttributeFromParent()

Procedure SetCatalogShortFirstCode(CatalogObject,Length = 7) Export
	
	CatalogFirstCode = DocumentsPostingAndNumbering.GetCatalogFirstCode(CatalogObject);
	
	If StrLen(CatalogFirstCode) <= Length Then
		Return;
	EndIf;
	
	If CatalogObject.Code = CatalogFirstCode Then
		
		ShortCode = "";
		For x = 1 To Length-1 Do
			ShortCode = ShortCode + "0";
		EndDo;
		
		CatalogObject.Code = ShortCode + "1";
		
	EndIf;	
	
EndProcedure	

Procedure DoCommonCheck(Object,Cancel = False) Export
	
	If Object = Undefined Then 
		Return;
	EndIf;
	
	If Documents.AllRefsType().ContainsType(TypeOf(Object.Ref))
		OR Tasks.AllRefsType().ContainsType(TypeOf(Object.Ref))
		OR BusinessProcesses.AllRefsType().ContainsType(TypeOf(Object.Ref)) Then
		Try
			Object.DocumentChecks(Cancel);
		Except
			If TrimAll(ErrorInfo().SourceLine) <> "Object.DocumentChecks(Cancel);" Then
				Raise(ErrorDescription());
			EndIf;	
		EndTry;
		
		Try
			Object.DocumentChecksTabularPart(Cancel);
		Except
			If TrimAll(ErrorInfo().SourceLine) <> "Object.DocumentChecksTabularPart(Cancel);" Then
				Raise(ErrorDescription());
			EndIf;	
		EndTry;
		
	Else
		Try
			Object.ElementChecks(Cancel);
		Except
			If TrimAll(ErrorInfo().SourceLine) <> "Object.ElementChecks(Cancel);" Then
				Raise(ErrorDescription());
			EndIf;
		EndTry;
	EndIf;	
	
EndProcedure	

Function GetAttributeFromRef(Val Ref,Val AttributeName,Cancel = False, Val Silent = False) Export
	
	If Ref = Undefined Then
		If NOT Silent Then
			CommonAtClientAtServer.NotifyUser(CommonAtClientAtServer.ParametrizeString(Nstr("en = 'Error reading object''s %P1 attribute %P2. Object is Undefined!'; pl = 'Błąd odczytu atrybutu %P2 dla %P1. Objekt jest wartością ""Undefined""!'"),New Structure("P1, P2",Ref,AttributeName)),Ref,,,Cancel);
		EndIf;	
		Return Undefined;
	EndIf;	

	MetadataClassName = ObjectsExtensionsAtServer.GetMetadataClassName(TypeOf(Ref));
	MetadataName = Ref.Metadata().Name;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	             |	ObjectTable."+AttributeName+" AS " + AttributeName + "
	             |FROM
	             |	"+MetadataClassName+"."+MetadataName+" AS ObjectTable
	             |WHERE
	             |	ObjectTable.Ref = &Ref";
	Query.SetParameter("Ref",Ref);
	Try
		QueryResult = Query.Execute();
	Except
		If NOT Silent Then
			CommonAtClientAtServer.NotifyUser(CommonAtClientAtServer.ParametrizeString(Nstr("en = 'Error reading object''s %P1 attribute %P2!'; pl = 'Błąd odczytu atrybutu %P2 dla %P1!'"),New Structure("P1, P2",Ref,AttributeName)),Ref,,,Cancel);
		EndIf;	
		Return Undefined;
	EndTry;	
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection[AttributeName];
		
	Else
		ObjectMetadata = Metadata.FindByFullName(MetadataClassName+"."+MetadataName);
		AttributeMetadata = ObjectMetadata.Attributes[AttributeName];
		AttributeType = AttributeMetadata.Type;
		If AttributeType.Types().Count() > 1 Then
			ReadingFailureValue = Undefined;
		Else
			ReadingFailureValue = EmptyValueType(AttributeType.Types()[0]);
		EndIf;	
	EndIf;	
	
	If ValueIsFilled(Ref) Then
		CommonAtClientAtServer.NotifyUser(CommonAtClientAtServer.ParametrizeString(Nstr("en = 'Error reading object''s %P1 attribute %P2!'; pl = 'Błąd odczytu atrybutu %P2 dla %P1!'"),New Structure("P1, P2",Ref,AttributeName)),Ref,,,Cancel);
	EndIf;
	
	Return ReadingFailureValue;
	
EndFunction	

Function GetAttributesStructureFromRef(Val Ref,Val NamesStructure,Cancel = False) Export
	
	ReturnStructure = New Structure;
	For Each KeyAndValue In NamesStructure Do
		
		ReturnStructure.Insert(KeyAndValue.Key,GetAttributeFromRef(Ref,KeyAndValue.Key,Cancel));
		
	EndDo;	
	
	Return ReturnStructure;
	
EndFunction	

Function GetChangesArrayForBusinessPartnersAttributesHistory(ObjectRef,Parameters, BaseStructure = False) Export
	
	WriteDate = CurrentDate();

	Query = New Query;
	Query.Text = "SELECT
	             |	BusinessPartnersAttributesHistorySliceLast.Period,
	             |	BusinessPartnersAttributesHistorySliceLast.Attribute,
	             |	BusinessPartnersAttributesHistorySliceLast.Country,
	             |	BusinessPartnersAttributesHistorySliceLast.Description,
	             |	BusinessPartnersAttributesHistorySliceLast.Field1,
	             |	BusinessPartnersAttributesHistorySliceLast.Field2,
	             |	BusinessPartnersAttributesHistorySliceLast.Field3,
	             |	BusinessPartnersAttributesHistorySliceLast.Field4,
	             |	BusinessPartnersAttributesHistorySliceLast.Field5,
	             |	BusinessPartnersAttributesHistorySliceLast.Field6,
	             |	BusinessPartnersAttributesHistorySliceLast.Field7,
	             |	BusinessPartnersAttributesHistorySliceLast.Field8,
	             |	BusinessPartnersAttributesHistorySliceLast.Field9,
	             |	BusinessPartnersAttributesHistorySliceLast.Field10
	             |FROM
	             |	InformationRegister.BusinessPartnersAttributesHistory.SliceLast(&Period, ) AS BusinessPartnersAttributesHistorySliceLast
	             |WHERE
	             |	BusinessPartnersAttributesHistorySliceLast.BusinessPartner = &Customer
	             |;
	             |
	             |////////////////////////////////////////////////////////////////////////////////
	             |SELECT
	             |	BusinessPartnersAttributesHistorySliceLast.Country
	             |FROM
	             |	InformationRegister.BusinessPartnersAttributesHistory.SliceLast(&Period, ) AS BusinessPartnersAttributesHistorySliceLast
	             |WHERE
	             |	BusinessPartnersAttributesHistorySliceLast.BusinessPartner = &Customer
	             |	AND Not BusinessPartnersAttributesHistorySliceLast.Country = VALUE(Catalog.Countries.EmptyRef)
	             |
	             |GROUP BY
	             |	BusinessPartnersAttributesHistorySliceLast.Country";
	
	Query.SetParameter("Period", WriteDate);
	Query.SetParameter("Customer", ObjectRef);
	
	SelectionTable = Query.ExecuteBatch()[0].Unload();
	SelectionCountry = Query.ExecuteBatch()[1].Unload();
	
	LongDescriptionIsEqualToHistory = Undefined;
	VATNumberIsEqualToHistory       = Undefined;
	LegalAddressIsEqualToHistory    = Undefined;
	
	AttributesForChange = New Array;

	For Each BusinessPartnersAttributesTypeName In Metadata.Enums.BusinessPartnersAttributesTypes.EnumValues Do
		
		NewAttributeValue = Undefined;
		EnumValue = Enums.BusinessPartnersAttributesTypes[BusinessPartnersAttributesTypeName.Name];
		FoundValuesTable = SelectionTable.FindRows(New Structure("Attribute, Country", EnumValue, Catalogs.Countries.EmptyRef()));
		NoRecordsKey = False;
		NeedToWriteCurrentValue = False;
		AttributeName = "";
		
		CurrentStructureFields = New Structure;
		NewStructureFields = New Structure;
		For i = 1 To 10 Do
			NewStructureFields.Insert("Field" + Format(i, "NG="), "");
			CurrentStructureFields.Insert("Field" + Format(i, "NG="), "");
		EndDo;
		
		If FoundValuesTable.Count()>0 Then
			FoundValueRow = FoundValuesTable[0];
			CurrentAttributeValue = FoundValueRow.Description;
			CurrentAttributePeriod = FoundValueRow.Period;
			For i = 1 to 10 Do
				CurrentStructureFields["Field" + Format(i, "NG=")] = FoundValueRow["Field" + Format(i, "NG=")];
			EndDo;
		Else
			NoRecordsKey = True;
			CurrentAttributeValue = "";
			CurrentAttributePeriod = "";
		EndIf;	
		
		If EnumValue = Enums.BusinessPartnersAttributesTypes.LongDescription AND Parameters.Property("LongDescription") Then
			LongDescriptionIsEqualToHistory = (CurrentAttributeValue = Parameters.LongDescription);
			If Not LongDescriptionIsEqualToHistory Then
				NeedToWriteCurrentValue = True;
				NewAttributeValue = Parameters.LongDescription;
			EndIf;
			AttributeName = "LongDescription";
		EndIf;
		
		If EnumValue = Enums.BusinessPartnersAttributesTypes.VATNumber AND Parameters.Property("VATNumber") Then
			VATNumberIsEqualToHistory = (CurrentAttributeValue = Parameters.VATNumber);
			If Not VATNumberIsEqualToHistory Then	
				NeedToWriteCurrentValue = True;
				NewAttributeValue = Parameters.VATNumber;
			EndIf;
			AttributeName = "VATNumber";
		EndIf;
		
		If EnumValue = Enums.BusinessPartnersAttributesTypes.LegalAddress AND Parameters.Property("LegalAddress") Then
			LegalAddressIsEqualToHistory = (CurrentAttributeValue = Parameters.LegalAddress);
			For i = 1 To 10 Do
				NewStructureFields["Field" + Format(i, "NG=")] = Parameters["Field" + Format(i, "NG=")];
				LegalAddressIsEqualToHistory = (CurrentStructureFields["Field" + Format(i, "NG=")] = Parameters["Field" + Format(i, "NG=")]);
			EndDo;
			If Not LegalAddressIsEqualToHistory Then
				NeedToWriteCurrentValue = True;
				NewAttributeValue = Parameters.LegalAddress;
			EndIf;
			AttributeName = "LegalAddress";
		EndIf;

		If NeedToWriteCurrentValue Or BaseStructure Then
			ArrayStructure = New Structure;	
			ArrayStructure.Insert("Attribute",EnumValue);
			ArrayStructure.Insert("Country", Undefined);
			ArrayStructure.Insert("CurrentAttributePeriod",CurrentAttributePeriod);
			ArrayStructure.Insert("CurrentAttributeValue",CurrentAttributeValue);
			ArrayStructure.Insert("CurrentStructureFields", ?(AttributeName = "LegalAddress", CurrentStructureFields, Undefined));
			ArrayStructure.Insert("NewAttributePeriod",?(NoRecordsKey,'19000101000000',BegOfDay(WriteDate)));
			ArrayStructure.Insert("NewAttributeValue",NewAttributeValue);
			ArrayStructure.Insert("NewStructureFields", ?(AttributeName = "LegalAddress", NewStructureFields, Undefined));
			ArrayStructure.Insert("FirstValue",NoRecordsKey);
			ArrayStructure.Insert("AttributeName", AttributeName);
			AttributesForChange.Add(ArrayStructure);
		EndIf;
	
	EndDo;
	
	For Each RowCountry In SelectionCountry Do
		
		EnumValue = Enums.BusinessPartnersAttributesTypes.VATNumber;
		
		NewAttributeValue = Undefined;
		FoundValuesTable = SelectionTable.FindRows(New Structure("Attribute, Country",EnumValue, RowCountry.Country));
		NoRecordsKey = False;
		NeedToWriteCurrentValue = False;
		AttributeName = "";
		
		CurrentStructureFields = New Structure;
		NewStructureFields = New Structure;
		For i = 1 To 10 Do
			NewStructureFields.Insert("Field" + Format(i, "NG="), "");
			CurrentStructureFields.Insert("Field" + Format(i, "NG="), "");
		EndDo;
		
		If FoundValuesTable.Count()>0 Then
			FoundValueRow = FoundValuesTable[0];
			CurrentAttributeValue = FoundValueRow.Description;
			CurrentAttributePeriod = FoundValueRow.Period;
			For i = 1 to 10 Do
				CurrentStructureFields["Field" + Format(i, "NG=")] = FoundValueRow["Field" + Format(i, "NG=")];
			EndDo;
		Else
			NoRecordsKey = True;
			CurrentAttributeValue = "";
			CurrentAttributePeriod = "";
		EndIf;	
		
		If EnumValue = Enums.BusinessPartnersAttributesTypes.LongDescription AND Parameters.Property("LongDescription") Then
			LongDescriptionIsEqualToHistory = (CurrentAttributeValue = Parameters.LongDescription);
			If Not LongDescriptionIsEqualToHistory Then
				NeedToWriteCurrentValue = True;
				NewAttributeValue = Parameters.LongDescription;
			EndIf;
			AttributeName = "LongDescription";
		EndIf;
		
		If EnumValue = Enums.BusinessPartnersAttributesTypes.VATNumber AND Parameters.Property("VATNumber") Then
			If ValueIsFilled(RowCountry.Country) Then
				VATNumber = Parameters.OtherCountryVATNumbers.Get(RowCountry.Country);
				VATNumberIsEqualToHistory = (CurrentAttributeValue = VATNumber);
				If VATNumberIsEqualToHistory Then
					NewAttributeValue = Undefined;
				Else
					NeedToWriteCurrentValue = True;
					NewAttributeValue = VATNumber;
				EndIf;
			Else
				VATNumberIsEqualToHistory = (CurrentAttributeValue = Parameters.VATNumber);
				If Not VATNumberIsEqualToHistory Then	
					NeedToWriteCurrentValue = True;
					NewAttributeValue = Parameters.VATNumber;
				EndIf;
			EndIf;
			AttributeName = "VATNumber";
		EndIf;
		
		If NeedToWriteCurrentValue Or BaseStructure Then
			ArrayStructure = New Structure;	
			ArrayStructure.Insert("Attribute",EnumValue);
			ArrayStructure.Insert("Country", RowCountry.Country);
			ArrayStructure.Insert("CurrentAttributePeriod",CurrentAttributePeriod);
			ArrayStructure.Insert("CurrentAttributeValue",CurrentAttributeValue);
			ArrayStructure.Insert("CurrentStructureFields", ?(AttributeName = "LegalAddress", CurrentStructureFields, Undefined));
			ArrayStructure.Insert("NewAttributePeriod",?(NoRecordsKey,'19000101000000',BegOfDay(WriteDate)));
			ArrayStructure.Insert("NewAttributeValue",NewAttributeValue);
			ArrayStructure.Insert("NewStructureFields", ?(AttributeName = "LegalAddress", NewStructureFields, Undefined));
			ArrayStructure.Insert("FirstValue",NoRecordsKey);
			ArrayStructure.Insert("AttributeName", AttributeName);
			AttributesForChange.Add(ArrayStructure);
		EndIf;
    EndDo;
	
	Return AttributesForChange;
	
EndFunction	

Function GetMetadataName(ObjectRef) Export
	
	Return ObjectRef.Metadata().Name;
	
EndFunction	

Procedure TableUniquenessRowValidation(Object, CheckedTable, KeyColumnNamesAsString, Cancel, Form = Undefined, IdentificationColumnName = "LineNumber", AlertStatus = Undefined) Export
	
	KeyColumnNames = New Structure(KeyColumnNamesAsString);
	ColumnPresentationsString = ""; // this one will be filled in the iteration below
	
	//presentation variables used for displaying messages
	If TypeOf(CheckedTable) = Type("String") Then
		
		TabularPart = Object[CheckedTable];
		TabularPartMetadata = Object.Metadata().TabularSections[CheckedTable];
		TabularPartPresentation = TabularPartMetadata.Presentation();
		
		For Each ColumnKeyAndValue In KeyColumnNames Do
			ColumnPresentationsString = ColumnPresentationsString + StringFunctionsClientServer.AddStringSeparator(ColumnPresentationsString) + TabularPartMetadata.Attributes[ColumnKeyAndValue.Key].Presentation();
		EndDo;
		
		//create a ValueTable initially containing original tabular part
		TabularPartClone = TabularPart.Unload();
		
	ElsIf TypeOf(CheckedTable) = Type("Structure") Then
		
		TabularPart = CheckedTable.Table;
		TabularPartColumnsPresentations = CheckedTable.ColumnsPresentations;
		TabularPartPresentation = CheckedTable.Presentation;
		
		For Each ColumnKeyAndValue In KeyColumnNames Do
			
			ColumnPresentation = "";
			TabularPartColumnsPresentations.Property(ColumnKeyAndValue.Key, ColumnPresentation);
			If ValueIsFilled(ColumnPresentation) Then
				ColumnPresentationsString = ColumnPresentationsString + StringFunctionsClientServer.AddStringSeparator(ColumnPresentationsString) + ColumnPresentation;
			Else
				ColumnPresentationsString = ColumnPresentationsString + StringFunctionsClientServer.AddStringSeparator(ColumnPresentationsString) + ColumnKeyAndValue.Key;
			EndIf;
			
		EndDo;
		
		//create a ValueTable initially containing original tabular part
		TabularPartClone = TabularPart.Unload();
		
	EndIf;
	
	//get row values (if such rows exist) which are duplicated in tabular part
	TabularPartClone.Columns.Add("RowCount"); //add a column which will count how many such row appears in tabular table
	TabularPartClone.FillValues(1, "RowCount");
	TabularPartClone.GroupBy(KeyColumnNamesAsString, "RowCount");
	
	RowsAreDuplicated = False;
	RowFilters = New Array; //Array of Structure, containing all row filters, one per duplicated rows set
	
	DuplicatedRowValues = New Array(KeyColumnNames.Count()); //this will be used to copy values of row encountered more than once
	
	// Find duplicates occurance
	For Each TabularPartCloneRow In TabularPartClone Do
		
		If TabularPartCloneRow.RowCount > 1 Then //this is a duplicated row
			
			RowsAreDuplicated = True;
			
			RowFilter = New Structure; // this will contain criteria for future searching of duplicated rows in tabular part
			
			// Retrieve values that are in a duplicated row.
			For Each KeyAndValue In KeyColumnNames Do
				RowFilter.Insert(KeyAndValue.Key, TabularPartCloneRow[KeyAndValue.Key]); //form filter for row searching
			EndDo;
			
			// Store new row filter for duplicated rows set.
			RowFilters.Add(RowFilter);
			
		EndIf;
		
	EndDo;
	
	OutMessageTitle = NStr("en = 'Tabular part'; pl = 'Częśc tabelarycza'") + " """ + TabularPartPresentation;
	
	//if there are duplicated rows, find them and return appropriate message
	If RowsAreDuplicated Then
		
		For Each RowFilter in RowFilters Do
			
			DuplicatedRows = TabularPart.FindRows(RowFilter);
			OutMessage = OutMessageTitle + """, " + NStr("en = 'there are duplicated rows'; pl = 'zduplikowane wiersze'") + ": " + DuplicatedRows[0][IdentificationColumnName];
			
			For i = 1 To DuplicatedRows.UBound() Do
				OutMessage = OutMessage + ", " + DuplicatedRows[i][IdentificationColumnName];
			EndDo;
			
			CommonAtClientAtServer.NotifyUser(OutMessage,Object,,,Cancel, AlertStatus);
			If AlertStatus = Enums.AlertType.Error Then
				Continue;
			EndIf;
			
			AdditionalTarger = "";
			Try
				AdditionalTarger = Object.AdditionalProperties.FormOwnerUUID;
			Except
			EndTry;
			
			If Not AdditionalTarger = "" Then
				CommonAtClientAtServer.NotifyUser(OutMessage,Object,,,Cancel, AlertStatus, AdditionalTarger);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure //TableRowUniquenessValidation

Function GetMetadataByType(Type) Export

	Return Metadata.FindByType(Type);
	
EndFunction

Function GetMetadataNameByType(Type) Export

	Return Metadata.FindByType(Type).Name;
	
EndFunction

Function GetMetadataClassName(ObjectRefType) Export
	
	If Catalogs.AllRefsType().ContainsType(ObjectRefType) Then
		Return ObjectsExtensionsAtClientAtServerCached.GetCatalogMetadataClassName();
	ElsIf Documents.AllRefsType().ContainsType(ObjectRefType) Then	
		Return ObjectsExtensionsAtClientAtServerCached.GetDocumentMetadataClassName();
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(ObjectRefType) Then
		Return "ChartOfAccounts";
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(ObjectRefType) Then
		Return "ChartOfCalculationTypes";
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(ObjectRefType) Then
		Return "ChartOfCharacteristicTypes";
	ElsIf ExchangePlans.AllRefsType().ContainsType(ObjectRefType) Then
		Return "ExchangePlan";
	ElsIf Enums.AllRefsType().ContainsType(ObjectRefType) Then
		Return "Enum";
	EndIf;		
	
EndFunction	

Function GetMetadataClassPictureIndex(MetadataFullName) Export
	
	MetadataObjectClassInstance = Metadata.FindByFullName(MetadataFullName);
	If Metadata.Constants.Contains(MetadataObjectClassInstance) Then
		Return 1;
	ElsIf Metadata.Catalogs.Contains(MetadataObjectClassInstance) Then	
		Return 3;
	ElsIf Metadata.Sequences.Contains(MetadataObjectClassInstance) Then	
		Return 5;
	ElsIf Metadata.Documents.Contains(MetadataObjectClassInstance) Then	
		Return 7;
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObjectClassInstance) Then	
		Return 9;
	ElsIf Metadata.ChartsOfAccounts.Contains(MetadataObjectClassInstance) Then	
		Return 11;
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(MetadataObjectClassInstance) Then	
		Return 13;	
	ElsIf Metadata.InformationRegisters.Contains(MetadataObjectClassInstance) Then	
		Return 15;	
	ElsIf Metadata.AccumulationRegisters.Contains(MetadataObjectClassInstance) Then	
		Return 17;		
	ElsIf Metadata.AccountingRegisters.Contains(MetadataObjectClassInstance) Then	
		Return 19;			
	ElsIf Metadata.CalculationRegisters.Contains(MetadataObjectClassInstance) Then	
		Return 21;	
	ElsIf Metadata.BusinessProcesses.Contains(MetadataObjectClassInstance) Then	
		Return 23;		   
	ElsIf Metadata.Tasks.Contains(MetadataObjectClassInstance) Then	
		Return 25;			
	Else
		Return 0;
	EndIf;	
	
EndFunction	

Function GetDefaultObjectFormPathByRef(ObjectRef) Export
	
	Return GetMetadataClassName(TypeOf(ObjectRef))+"."+GetMetadataName(ObjectRef)+"."+"ObjectForm";
	
EndFunction	

// Procedure used to filling general form attributes
// Called from handlers on "OnOpen" events in all form modules in documents
//
// Parameters:
//  DocumentObject                 - editing document object
Procedure FillDocumentHeader(DocumentObject) Export 
	
	DocumentMetadata = DocumentObject.Metadata();
	
	// Author changing without filling check.
	If ObjectsExtensionsAtServer.IsDocumentAttribute("Author", DocumentMetadata) Then
		DocumentObject.Author = SessionParameters.CurrentUser;
	EndIf;
	
	If ObjectsExtensionsAtServer.IsDocumentAttribute("Company", DocumentMetadata) AND ValueIsNotFilled(DocumentObject.Company) Then
		DocumentObject.Company = CommonAtServer.GetUserSettingsValue("Company");
	EndIf;
	
	If ObjectsExtensionsAtServer.IsDocumentAttribute("Warehouse", DocumentMetadata) AND ValueIsNotFilled(DocumentObject.Warehouse) Then
		DocumentObject.Warehouse = CommonAtServer.GetUserSettingsValue("Warehouse");
	EndIf;
	
	If ObjectsExtensionsAtServer.IsDocumentAttribute("Department", DocumentMetadata) AND ValueIsNotFilled(DocumentObject.Department) Then
		DocumentObject.Department = CommonAtServer.GetUserSettingsValue("Department");
	EndIf;
	
EndProcedure // FillDocumentHeader()

// Returns default value of remarks for combination of document and customer/supplier
Function GetDocumentRemarksStructure(Val DocumentObject, Val BusinessPartner = Undefined) Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	DocumentRemarks.Remarks AS Remarks,
	             |	CASE
	             |		WHEN DocumentRemarks.BusinessPartner = &EmptyBusinessPartner
	             |			THEN 1
	             |		ELSE 0
	             |	END AS BusinessPartnerOrder,
	             |	DocumentRemarks.AdditionalInformation
	             |FROM
	             |	InformationRegister.DocumentRemarks AS DocumentRemarks
	             |WHERE
	             |	DocumentRemarks.DocumentType = &DocumentType
	             |	AND (DocumentRemarks.BusinessPartner = &BusinessPartner
	             |			OR DocumentRemarks.BusinessPartner = &EmptyBusinessPartner)
	             |
	             |ORDER BY
	             |	BusinessPartnerOrder";
	
	Query.SetParameter("DocumentType", New(TypeOf(DocumentObject.Ref)));
	Query.SetParameter("BusinessPartner", BusinessPartner);
	Query.SetParameter("EmptyBusinessPartner", Undefined);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return New Structure("Remarks, AdditionalInformation",Selection.Remarks,Selection.AdditionalInformation);
	Else
		Return New Structure("Remarks, AdditionalInformation","","");
	EndIf;
	
EndFunction

// for documents and catalogs onlyinfo 
Function FormDataStructureToStructure(Val FormDataStructure) Export
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("Ref",FormDataStructure.Ref);
	
	ObjectMetadata = FormDataStructure.Ref.Metadata();
	
	ArrayOfArrays = New Array();
	ArrayOfArrays.Add(ObjectMetadata.StandardAttributes);
	ArrayOfArrays.Add(ObjectMetadata.Attributes);
	
	For Each ArrayItem In ArrayOfArrays Do
		For Each Attribute In ArrayItem Do
			ReturnStructure.Insert(Attribute.Name,FormDataStructure[Attribute.Name]);
		EndDo;	
	EndDo;	
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		AutoUse = CommonAttribute.AutoUse = Metadata.ObjectProperties.CommonAttributeUse.Use;
		IsAttribute = (CommonAttribute.Content.Find(ObjectMetadata).Use = Metadata.ObjectProperties.CommonAttributeUse.Use)
			Or (AutoUse And CommonAttribute.Content.Find(ObjectMetadata).Use = Metadata.ObjectProperties.CommonAttributeUse.Auto);
		
		If IsAttribute Then
			ReturnStructure.Insert(CommonAttribute.Name, FormDataStructure[CommonAttribute.Name]);
		EndIf;
	EndDo;
	
	Return ReturnStructure;
	
EndFunction	
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CHECKING EXISTENCE AND FILLING OF ATTRIBUTES

Function IsDocumentAttribute(AttributeName, DocumentMetadata) Export 

	Return Not (DocumentMetadata.Attributes.Find(AttributeName) = Undefined);

EndFunction // ObjectsExtensionsAtServer.IsDocumentAttribute()

Function IsDocumentTabularPart(TabularPartName, DocumentMetadata) Export 

	Return Not (DocumentMetadata.TabularSections.Find(TabularPartName) = Undefined);

EndFunction // ObjectsExtensionsAtServer.IsDocumentTabularPart()

Function IsDocumentTabularPartAttribute(AttributeName, DocumentMetadata, TabularPartName) Export 
	
	TabularPart = DocumentMetadata.TabularSections.Find(TabularPartName);
	
	If TabularPart = Undefined Then
		Return False;
	Else
		Return Not (TabularPart.Attributes.Find(AttributeName) = Undefined);
	EndIf;

EndFunction // ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute()

Function GetEnumNameByValue(Val EnumValue) Export
	
	If ValueIsFilled(EnumValue) Then
		
		EnumName = EnumValue.Metadata().Name;
		Return Metadata.Enums[EnumName].EnumValues[Enums[EnumName].IndexOf(EnumValue)].Name;
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction // GetEnumNameByValue()

Function GetDocumentNumberLength(Val DocumentRef) Export
	Return DocumentRef.Metadata().NumberLength;
EndFunction	
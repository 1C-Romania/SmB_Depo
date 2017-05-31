Procedure AddVATNumbersItems(Form)
	Index = 0;
	For Each AttributeForChange In Form.AttributesForChange Do
		If Not (AttributeForChange.Attribute = Enums.BusinessPartnersAttributesTypes.VATNumber 
			And ValueIsFilled(AttributeForChange.Country) And Not AttributeForChange.Country = Catalogs.Countries.Poland) Then
			
			Continue;
		EndIf;

		NewRow = Form.VATNumbers.Add();
		NewRow.Country = AttributeForChange.Country;
		NewRow.VATNumber = AttributeForChange.CurrentAttributeValue;
		
		NewGroupe = Form.Items.Add(StrReplace("Groupe" + AttributeForChange.Country.Code, " ", ""), Type("FormGroup"), Form.Items.GroupVATNumbers);
		NewGroupe.Type = FormGroupType.UsualGroup;
		NewGroupe.ShowTitle = False;
		NewGroupe.Representation = UsualGroupRepresentation.None;
		NewGroupe.Group = ChildFormItemsGroup.Horizontal;
		
	 	NewVATNumberCountry = Form.Items.Add(StrReplace("VATCountry" + AttributeForChange.Country.Code, " ", ""), Type("FormField"), NewGroupe);
		NewVATNumberCountry.TitleLocation = FormItemTitleLocation.None;
		NewVATNumberCountry.Type = FormFieldType.LabelField;
		NewVATNumberCountry.DataPath = "VATNumbers[" + Format(Index,"NG=") + "].Country";
		NewVATNumberCountry.HorizontalStretch = False;
		
		NewVATNumber = Form.Items.Add(StrReplace("VATNumber" + AttributeForChange.Country.Code, " ", ""), Type("FormField"), NewGroupe);
		NewVATNumber.TitleLocation = FormItemTitleLocation.None;
		NewVATNumber.Type = FormFieldType.InputField;
		NewVATNumber.HorizontalStretch = True;
		NewVATNumber.AutoMaxWidth = False;
		NewVATNumber.ReadOnly = True;
		NewVATNumber.DataPath = "VATNumbers[" + Format(Index,"NG=") + "].VATNumber";

		Index = Index + 1;
	EndDo;
EndProcedure

Function GetObjectManager(Val ObjectMetadataFullName) Export
	ObjectManager = Undefined;
	
	MetadataTypeName = Left(ObjectMetadataFullName, Find(ObjectMetadataFullName, ".")-1);
	ObjectMetadataName = Right(ObjectMetadataFullName, StrLen(ObjectMetadataFullName) - Find(ObjectMetadataFullName, "."));
	
	If MetadataTypeName = "Catalog" Then
		ObjectManager = Catalogs[ObjectMetadataName];
	ElsIf MetadataTypeName = "Document" Then
		ObjectManager = Documents[ObjectMetadataName];
	ElsIf MetadataTypeName = "BusinessProcess" Then
		ObjectManager = BusinessProcesses[ObjectMetadataName];
	ElsIf MetadataTypeName = "ChartOfCharacteristicTypes" Then
		ObjectManager = ChartsOfCharacteristicTypes[ObjectMetadataName];
	ElsIf MetadataTypeName = "ChartOfAccounts" Then
		ObjectManager = ChartsOfAccounts[ObjectMetadataName];
	ElsIf MetadataTypeName = "ChartOfCalculationTypes" Then
		ObjectManager = ChartsOfCalculationTypes[ObjectMetadataName];
	ElsIf MetadataTypeName = "Task" Then
		ObjectManager = Tasks[ObjectMetadataName];
	ElsIf MetadataTypeName = "ExchangePlan" Then
		ObjectManager = ExchangePlans[ObjectMetadataName];
	ElsIf MetadataTypeName = "Enum" Then
		ObjectManager = Enums[ObjectMetadataName];
	EndIf;
	
	Return ObjectManager;
EndFunction

Function GetNewObjectRef(Val ObjectMetadataFullName) Export
	ObjectManager = GetObjectManager(ObjectMetadataFullName);
	NewRef = ObjectManager.GetRef(New UUID);
	Return NewRef;
EndFunction

Procedure FillNewObject(Form, ObjectMetadata) Export
	Form.NewRef = GetNewObjectRef(ObjectMetadata.FullName());
EndProcedure

Procedure AddStandartObjectAttributes(Form, FormInformation)
	NewAttributes = New Array;
	For Each StandartAttribute In DocumentsFormAtServerCached.GetStandartsObjectAttributes() Do
		If Not FormInformation.IsAttribute[StandartAttribute.Key] Then 
			NewAttribute = New FormAttribute(StandartAttribute.Key, StandartAttribute.Value.Type, , "");
			NewAttributes.Add(NewAttribute);
		EndIf;
	EndDo;
	
	If NewAttributes.Count() > 0 Then
		Form.ChangeAttributes(NewAttributes);
	EndIf;
	
	Form.FormInformation = New FixedStructure(FormInformation);
	Form.ObjectTitle = CommonAtServer.GetObjectTitle(Form.Object.Ref);
	
	MetadataAttributes = New Structure;
	For Each Attribute In Form.Object.Ref.Metadata().Attributes Do 
		MetadataAttributes.Insert(Attribute.Name);
	EndDo;
	Form.HeaderAttributes = New FixedStructure(MetadataAttributes);
EndProcedure

// Common handler for catalog forms
Procedure CatalogFormOnCreateAtServer(Form, Cancel, StandardProcessing) Export

	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		HideAutoCommandsGroup(Form);
	ElsIf CurrentRunMode() = ClientRunMode.OrdinaryApplication Then
		CommonAtServer.AdjustFormGroupsToOrdinaryApplication(Form);
	EndIf;
	
	FormInformation = GetFormInformation(Form);
	
	If FormInformation.Type = "LIST" Then
		ListOnCreateAtServer(Form, FormInformation);
	ElsIf FormInformation.Type = "OBJECT" Then
		ObjectOnCreateAtServer(Form, FormInformation);
	EndIf;

EndProcedure	

Procedure HideAutoCommandsGroup(Form)
	
	AutoCommandsGroup = Form.ChildItems.Find("AutoCommandsGroup");
	If AutoCommandsGroup <> Undefined AND AutoCommandsGroup.Visible Then
		AutoCommandsGroup.Visible = False;
	EndIf;
	
EndProcedure	

Procedure SetCommandsInterface(Form, FormInformation)
	If Not Form.Items.Find("FormCommonCommandAddAdditionalAttribute") = Undefined Then
		Form.Items.FormCommonCommandAddAdditionalAttribute.OnlyInAllActions = True;
	EndIf;
	If Not Form.Items.Find("FormCommonCommandEditObjectFiles") = Undefined Then
		Form.Items.FormCommonCommandEditObjectFiles.OnlyInAllActions = True;
	EndIf;
EndProcedure

Procedure ObjectOnCreateAtServer(Form, FormInformation)
	
	ObjectMetadata = Form.Object.Ref.Metadata();
	If Common.IsDocumentTabularPart("LanguagesDescription", ObjectMetadata) Then
		LanguagesModulesServer.AddLanguagesItems(Form);
	EndIf;
	
	AddStandartObjectAttributes(Form, FormInformation);
	Form.ObjectMetadataName = ObjectMetadata.Name;

	AdditionalAttributesServer.PutAddititionalAttributesOnForm(Form);		
	
	SetCommandsInterface(Form, FormInformation);
	
	If Form.Object.Ref.IsEmpty() Then
		FillNewObject(Form, ObjectMetadata);
	EndIf;
	
	If FormInformation.IsBaseContactInformationList Then
		FillContactInformationList(Form);
	EndIf;
	
	If FormInformation.IsHistoricalAttributesToWrite Then
		PrepareHistoricalAttributesToWrite(Form);
	EndIf;
	
	FillingData = Undefined;
	If Form.Object.Ref.IsEmpty() And Form.Parameters.Property("FillingData", FillingData) And ValueIsFilled(FillingData) Then
		For Each ValueFillingData In FillingData Do
			Form.Object[ValueFillingData.Key] = ValueFillingData.Value;
		EndDo;
	EndIf;
	
EndProcedure

Procedure PrepareHistoricalAttributesToWrite(Form)
	Form.HistoricalAttributesToWrite = New Structure;
	If Upper(Form.ObjectMetadataName) = Upper("Suppliers") Then
		ContactInformationProfiles = Catalogs.ContactInformationProfiles.SupplierLegalAddress;
	ElsIf Upper(Form.ObjectMetadataName) = Upper("Companies") Then 
		ContactInformationProfiles = Catalogs.ContactInformationProfiles.CompanyLegalAddress;
	ElsIf Upper(Form.ObjectMetadataName) = Upper("Customers") Then 
		ContactInformationProfiles = Catalogs.ContactInformationProfiles.CustomerLegalAddress;
	Else
		ContactInformationProfiles = Undefined;
	EndIf;
	LegalAddress = "";
	
	FoundRows = Form.BaseContactInformationList.FindRows(New Structure("ContactInformationProfile", ContactInformationProfiles));
	
	CurrentValueAttributes = New Structure("LongDescription, VATNumber, LegalAddress, OtherCountryVATNumbers", Form.Object.LongDescription, Form.Object.VATNumber, LegalAddress, New MAP);
	For i = 1 to 10 Do
		CurrentValueAttributes.Insert("Field" + Format(i, "NG="), Undefined);
	EndDo;
	
	For Each FoundRow In FoundRows Do
		FillPropertyValues(CurrentValueAttributes, FoundRow);
		CurrentValueAttributes.LegalAddress = FoundRow.Description;
		Break;
	EndDo;	
	Query = New Query;
	Query.Text = "SELECT
	|	BusinessPartnersAttributesHistorySliceLast.Country,
	|	BusinessPartnersAttributesHistorySliceLast.Description
	|FROM
	|	InformationRegister.BusinessPartnersAttributesHistory.SliceLast(
	|			,
	|			BusinessPartner = &BusinessPartner
	|				AND NOT Country = VALUE(Catalog.Countries.EmptyRef)) AS BusinessPartnersAttributesHistorySliceLast";
	
	Query.SetParameter("BusinessPartner", Form.Object.Ref);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		CurrentValueAttributes.OtherCountryVATNumbers.Insert(Selection.Country, Selection.Description);
	EndDo;	
	
	Form.AttributesForChange = New FixedArray(ObjectsExtensionsAtServer.GetChangesArrayForBusinessPartnersAttributesHistory(Form.Object.Ref, CurrentValueAttributes, True));
	If Constants.UseUEVATNumbers.Get() Then
		AddVATNumbersItems(Form);
	EndIf;
EndProcedure

Procedure WriteHistoricalAttributes(Form, Cancel, CurrentObject, WriteParameters)
	For Each HistoricalAttributesToWriteItem In Form.HistoricalAttributesToWrite Do
		
		RecordManager = InformationRegisters.BusinessPartnersAttributesHistory.CreateRecordManager();
		RecordManager.Period          = HistoricalAttributesToWriteItem.Value.Period;
		RecordManager.BusinessPartner = CurrentObject.Ref;
		RecordManager.Attribute       = HistoricalAttributesToWriteItem.Value.Attribute;
		RecordManager.Description     = HistoricalAttributesToWriteItem.Value.Value;
		If Not HistoricalAttributesToWriteItem.Value.NewStructureFields = Undefined Then
			For i = 1 To 10 Do
				RecordManager["Field" + Format(i, "NG=")] = HistoricalAttributesToWriteItem.Value.NewStructureFields["Field" + Format(i, "NG=")];
			EndDo;
		EndIf;
		Try
			RecordManager.Write();
		Except
			CommonAtClientAtServer.NotifyUser(ErrorDescription(),CurrentObject,,,Cancel);
		EndTry;
		
	EndDo;
EndProcedure

Procedure OnWriteAtServer(Form, Cancel, CurrentObject, WriteParameters) Export
	If Form.FormInformation.IsHistoricalAttributesToWrite Then
		WriteHistoricalAttributes(Form, Cancel, CurrentObject, WriteParameters);
	EndIf;
EndProcedure

Procedure ListOnCreateAtServer(Form, FormInformation)
	If Not Form.Items.Find("List") = Undefined Then
		Form.Items.List.ChoiceMode = Form.Parameters.ChoiceMode;
	EndIf;
	If Form.Items.List.ChoiceMode Then
		Form.List.AutoSaveUserSettings = False;
		ListAttributesArray = Form.GetAttributes("List");
		For Each ListAttribute In ListAttributesArray Do
			ValueForFilter = Undefined;
			Form.Parameters.Property("Filter_" + ListAttribute.Name, ValueForFilter);
			If ValueIsFilled(ValueForFilter) Then
				DataCompositionAtClientAtServer.SetUserSettingFilter(Form.List.SettingsComposer.UserSettings, ListAttribute.Name, ValueForFilter, True,DataCompositionComparisonType.Equal);
			EndIf;
		EndDo;
	EndIf;
	SetCommandsInterface(Form, FormInformation);
EndProcedure

Function GetFormInformation(Form)
	FormInformation = New Structure();
	FormInformation.Insert("IsHistoricalAttributesToWrite", False);
	FormInformation.Insert("IsBaseContactInformationList", False);
	FormInformation.Insert("Type");
	
	//Structure whith form attributes availability
	AttributesArray = Form.GetAttributes();
	AttributesAvailability = New Structure;
	FormInformation.Insert("IsAttribute", AttributesAvailability);
	For Each StandartAttribute In DocumentsFormAtServerCached.GetStandartsObjectAttributes() Do 
		IsAttributeAtForm = False;
		For Each AttributFormInfo In AttributesArray Do
			If Upper(AttributFormInfo.Name) = Upper("HistoricalAttributesToWrite") Then
				FormInformation.IsHistoricalAttributesToWrite = True;
			EndIf;
			If Upper(AttributFormInfo.Name) = Upper("BaseContactInformationList") Then
				FormInformation.IsBaseContactInformationList = True;
			EndIf;
			If AttributFormInfo.Name = StandartAttribute.Key Then
				IsAttributeAtForm = True;
				Break;
			EndIf;
		EndDo;
		AttributesAvailability.Insert(StandartAttribute.Key, IsAttributeAtForm);
	EndDo;

	For Each Attribute In AttributesArray Do
		If Upper(Attribute.Name) = "LIST" OR Upper(Attribute.Name) = "OBJECT" Then
			FormInformation.Type = Upper(Attribute.Name);
		EndIf;
	EndDo;
	
	Return FormInformation;
	
EndFunction

Procedure BeforeWriteAtServer(Form, Cancel, CurrentObject, WriteParameters) Export
	
	AdditionalAttributesServer.PutAddtitionalAttributeValuesOnStructure(Form, CurrentObject); 
	CurrentObject.AdditionalProperties.Insert("FormOwnerUUID", Form.FormOwnerUUID);
	If Common.IsDocumentTabularPart("LanguagesDescription", CurrentObject.Metadata()) Then
		ActualLanguages = LanguagesModulesServer.GetActualLanguages();
		SystemLanguage = LanguagesModulesServerCached.GetSystemLanguage();
		CurrentObject.LanguagesDescription.Clear();
		For Each Language In ActualLanguages Do
			If Language.Value.Ref = SystemLanguage Then
				Continue;
			EndIf;
			LanguagesModulesServer.SetLanguageDescription(CurrentObject, Language.Value.Ref, Form["LanguageValue" + Language.Value.Code], "Description");
		EndDo;
	EndIf;
	
	If CurrentObject.Ref.IsEmpty() Then
		ObjectMetadataFullName = CurrentObject.Metadata().FullName();
		MetadataTypeName = Left(ObjectMetadataFullName, Find(ObjectMetadataFullName, ".")-1);
		If MetadataTypeName = "Catalog" Then
			CurrentObject.SetNewCode();
			ObjectsExtensionsAtServer.SetCatalogShortFirstCode(CurrentObject);
		EndIf;
	EndIf;
	If CommonAtServer.IsDocumentAttribute("LongDescription", CurrentObject.Metadata())
		And CommonAtServer.IsDocumentAttribute("Description", CurrentObject.Metadata()) Then
		If Form.Items.Find("LongDescription") = Undefined Then
			CurrentObject.LongDescription = CurrentObject.Description;
		EndIf;
	EndIf;
EndProcedure

Procedure FillContactInformationList(Form) Export
	TmpRecordSet = Undefined;
	ContactInformationOrdinary.ReadContactInformation(TmpRecordSet, Form.Object.Ref);
	If Not TmpRecordSet = Undefined Then
		For Each Record In TmpRecordSet Do
			PlacedOnForm = True;
			If NOT IsBlankString(Record.ContactInformationProfile.PredefinedDataName) Then
				If Form.HeaderAttributes.Property(Record.ContactInformationProfile.PredefinedDataName) Then
					NewRow = Form.BaseContactInformationList.Add();
					Form.Object[Record.ContactInformationProfile.PredefinedDataName] = Record.Description;
				ElsIf Not Form.Items.Find(Record.ContactInformationProfile.PredefinedDataName) = Undefined Then
					NewRow = Form.BaseContactInformationList.Add();
					If Form.HeaderAttributes.Property(Record.ContactInformationProfile.PredefinedDataName) Then
						Form[Record.ContactInformationProfile.PredefinedDataName] = Record.Description;
					Else
						FormField = Form.Items.Find(Record.ContactInformationProfile.PredefinedDataName);
						DataPath = FormField.DataPath;
						Value = Form;
						While Find(DataPath, ".") > 0 Do
							Value = Value[Left(DataPath, Find(DataPath, ".") - 1)];
							DataPath = Right(DataPath, StrLen(DataPath) - Find(DataPath, "."));
						EndDo;
						Value[DataPath] = Record.Description;
					EndIf;
				Else
					PlacedOnForm = False;
				EndIf;
			Else
				PlacedOnForm = False;
			EndIf;
			If Not PlacedOnForm Then
				AddContactInformationAttribute(Form, Record.ContactInformationProfile, Record.Description);
				NewRow = Form.BaseContactInformationList.Add();		
			EndIf;	
			FillPropertyValues(NewRow, Record);
		EndDo;
	EndIf;
EndProcedure

Procedure WriteContactInformation(Form, ObjectType) Export
	
	ContactInformationRecordSet = InformationRegisters.ContactInformation.CreateRecordSet();
	ContactInformationRecordSet.Filter.Object.Set(Form.Object.Ref);
	ContactInformationRecordSet.Read();
	ContactInformationRecordSet.Clear();
	If Not Form.Items.Find("IsOtherDeliveryAddress") = Undefined Then
		If Not Form.IsOtherDeliveryAddress Then
			RowDeliweryAdress = Undefined;
			RowLegalAdress = Undefined;
			i = 0;
			
			
			For Each RowCI In Form.BaseContactInformationList Do
				If RowCI.ContactInformationProfile = Catalogs.ContactInformationProfiles[ObjectType + "LegalAddress"] Then
					RowLegalAdress = i;
				ElsIf RowCI.ContactInformationProfile = Catalogs.ContactInformationProfiles[ObjectType + "DeliveryAddress"] Then
					RowDeliweryAdress = i;
				EndIf;
				i = i + 1;
			EndDo;
			If Not RowDeliweryAdress = Undefined And Not RowLegalAdress = Undefined Then
				FillPropertyValues(Form.BaseContactInformationList[RowDeliweryAdress], Form.BaseContactInformationList[RowLegalAdress],,"Object,ContactInformationType,ContactInformationProfile");
			EndIf;
		EndIf;
	EndIf;
	
	For Each RowCI In Form.BaseContactInformationList Do
		NewRecord = ContactInformationRecordSet.Add();
		FillPropertyValues(NewRecord, RowCI);
		NewRecord.Object = Form.Object.Ref;
	EndDo;
	For Each RowCI In Form.ContactInformationList Do
		If Not ValueIsFilled(RowCI.Description) Then
			Continue;
		EndIf;
		NewRecord = ContactInformationRecordSet.Add();
		FillPropertyValues(NewRecord, RowCI);
		NewRecord.Object = Form.Object.Ref;
	EndDo;
	ContactInformationRecordSet.Write();
	
EndProcedure

Procedure AddContactInformationAttribute(Form, ContactProfile, Value)
	If TypeOf(ContactProfile) = Type("CatalogRef.ContactInformationProfiles") Then
		AttributeName = StrReplace("Contact_" + ContactProfile.Code, " ", "");
		AttributeProfileName = "Profile" + AttributeName;
		AttributeTile = ContactProfile.Description;
	Else
		AttributeName = StrReplace(ContactProfile, " ", "");
		AttributeProfileName = "Profile" + AttributeName;
		AttributeTile = ContactProfile;
	EndIf;
	NewContactAttribute = New FormAttribute(AttributeName, New TypeDescription("String", , , , New StringQualifiers(0)), , AttributeTile);
	NewContactProfileAttribute = New FormAttribute(AttributeProfileName, New TypeDescription("CatalogRef.ContactInformationProfiles"), , AttributeTile);
	
	NewAttributes = New Array;
	NewAttributes.Add(NewContactAttribute);
	NewAttributes.Add(NewContactProfileAttribute);
	Form.ChangeAttributes(NewAttributes);
	
 	NewAttributesItem = Form.Items.Add(AttributeName, Type("FormField"), Form.Items.GroupContactInformation);
	NewAttributesItem.TitleLocation = FormItemTitleLocation.Auto;
	NewAttributesItem.Type = FormFieldType.InputField;
	NewAttributesItem.DataPath = AttributeName;
	NewAttributesItem.HorizontalStretch = True;
	NewAttributesItem.OpenButton = True;
	NewAttributesItem.AutoMaxWidth = False;
	NewAttributesItem.SetAction("OnChange", "BaseContactInformationOnChange");
	NewAttributesItem.SetAction("Opening", "BaseContactInformationOpening");
	Form[AttributeName] = Value;
	Form[AttributeProfileName] = ContactProfile;
EndProcedure
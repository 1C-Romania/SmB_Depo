// Jack 23.06.2017 mybe deleted
//Procedure AddLanguagesItems(Form) Export
//	If Constants.UseMultiLanguagesDescriptions.Get() = False Then
//		Return;
//	EndIf;
//	SystemLanguage = LanguagesModulesServerCached.GetSystemLanguage();
//	ActualLanguages = GetActualLanguages();
//	CurrentLanguagesValue = GetCurrentFormLanguagesValue(Form);
//	For Each LanguageStructItem In ActualLanguages Do
//		Language = LanguageStructItem.Value;
//		If Language.Ref = SystemLanguage Then
//			Continue;
//		EndIf;
//		
//		NewGroupe = Form.Items.Add(StrReplace("Groupe" + Language.Code, " ", ""), Type("FormGroup"), Form.Items.GroupLanguages);
//		NewGroupe.Type = FormGroupType.UsualGroup;
//		NewGroupe.ShowTitle = False;
//		NewGroupe.Representation = UsualGroupRepresentation.None;
//		NewGroupe.Group = ChildFormItemsGroup.Horizontal;
//		
//		LanguageAttribute = New FormAttribute(StrReplace("Language" + Language.Code, " ", ""), New TypeDescription("CatalogRef.Languages"), , "");
//		LanguageAttributeValue = New FormAttribute(StrReplace("LanguageValue" + Language.Code, " ", ""), New TypeDescription("String", , , , New StringQualifiers(0)), , "");
//		NewAttributes = New Array;
//		NewAttributes.Add(LanguageAttribute);
//		NewAttributes.Add(LanguageAttributeValue);
//		Form.ChangeAttributes(NewAttributes);
//		
//	 	NewLanguageAttribute = Form.Items.Add(StrReplace("Language" + Language.Code, " ", ""), Type("FormField"), NewGroupe);
//		NewLanguageAttribute.TitleLocation = FormItemTitleLocation.None;
//		NewLanguageAttribute.Type = FormFieldType.LabelField;
//		NewLanguageAttribute.DataPath = StrReplace("Language" + Language.Code, " ", "");
//		NewLanguageAttribute.HorizontalStretch = False;
//		Form[StrReplace("Language" + Language.Code, " ", "")] = Language.Ref;
//		
//		NewAdditionalAttribute = Form.Items.Add(StrReplace("LanguageValue" + Language.Code, " ", ""), Type("FormField"), NewGroupe);
//		NewAdditionalAttribute.TitleLocation = FormItemTitleLocation.None;
//		NewAdditionalAttribute.Type = FormFieldType.InputField;
//		NewAdditionalAttribute.HorizontalStretch = True;
//		NewAdditionalAttribute.AutoMaxWidth = False;
//		NewAdditionalAttribute.DataPath = StrReplace("LanguageValue" + Language.Code, " ", "");
//		
//		Form[StrReplace("LanguageValue" + Language.Code, " ", "")] = GetLanguagesValue(Language.Ref, CurrentLanguagesValue.LanguagesValue);
//	EndDo;
//	
//EndProcedure

//Function GetCurrentFormLanguagesValue(Form) Export
//	
//	SystemLanguage = LanguagesModulesServerCached.GetSystemLanguage();
//	LanguagesValue = GetCurrentLanguagesValue(Form.Object, SystemLanguage, Form.Object.Description);
//	
//	Return New Structure("SystemLanguage,LanguagesValue", SystemLanguage, LanguagesValue);
//	
//EndFunction

//Function GetLanguagesValue(LanguageRef, InfoLanguagesValue) Export 
//	LanguagesValue = "";
//	For Each LanguagesValueInfo In InfoLanguagesValue Do
//		If LanguagesValueInfo.Value.Ref = LanguageRef Then
//			LanguagesValue = LanguagesValueInfo.Value.Description;
//			Break;
//		EndIf;
//	EndDo;
//	
//	Return LanguagesValue;
//EndFunction

//Function GetActualLanguages() Export
//	SystemLanguage = LanguagesModulesServerCached.GetSystemLanguage();
//	ReturnStructure = New Structure;
//	
//	Query = New Query;
//	
//	Query.Text = "SELECT
//	             |	Languages.Ref,
//	             |	Languages.Code,
//	             |	Languages.Presentation,
//	             |	CASE
//	             |		WHEN Languages.Ref = &SystemLanguage
//	             |			THEN 1
//	             |		ELSE 0
//	             |	END AS Order
//	             |FROM
//	             |	Catalog.Languages AS Languages
//	             |WHERE
//	             |	Languages.DeletionMark = FALSE
//	             |  And Languages.USE = True
//	             |ORDER BY
//	             |	Order DESC";
//				 
//	Query.SetParameter("SystemLanguage", SystemLanguage);
//	TempTable = Query.Execute().Unload();
//	q = 1;
//	For Each RowTempTable In TempTable Do
//		ItemStruct = New Structure("Ref, Code, Presentation", RowTempTable.Ref, RowTempTable.Code, RowTempTable.Presentation);
//		ReturnStructure.Insert("_" + Format(q, "NG="), ItemStruct);
//		q = q + 1;
//	EndDo;
//	
//	Return ReturnStructure;
//	
//EndFunction

//Procedure SetSystemLanguageDescription(Object, AttributeName = Undefined) Export
//	If Not ObjectsExtensionsAtServer.IsDocumentTabularPart("LanguagesDescription", Object.Metadata()) Then
//		Return;
//	EndIf;
//	
//	SystemLanguage = LanguagesModulesServerCached.GetSystemLanguage();
//	LanguagesFilters = New Structure("Language", SystemLanguage);
//	LanguagesRows = Object.LanguagesDescription.FindRows(LanguagesFilters);
//	If LanguagesRows.Count() = 0 Then
//		NewLanguageRow = Object.LanguagesDescription.Add();
//	Else
//		NewLanguageRow = LanguagesRows[0];
//	EndIf;
//	
//	NewLanguageRow.Language = SystemLanguage;
//	If AttributeName = Undefined Then
//		If ObjectsExtensionsAtServer.IsDocumentAttribute("LongDescription", Object.Metadata()) Then
//			NewLanguageRow.Description = Object.LongDescription;
//		Else
//			NewLanguageRow.Description = Object.Description;
//		EndIf;
//	Else
//		NewLanguageRow.Description = Object[AttributeName];
//	EndIf;
//	
//EndProcedure

//Procedure SetLanguageDescription(Object, Val Language, Value = Undefined, AttributeName = Undefined) Export
//	If TypeOf(Language) = Type("String") Then
//		Language = Catalogs.Languages.FindByCode(Language);
//	EndIf;
//	LanguagesFilters = New Structure("Language", Language);
//	LanguagesRows = Object.LanguagesDescription.FindRows(LanguagesFilters);
//	If LanguagesRows.Count() = 0 Then
//		NewLanguageRow = Object.LanguagesDescription.Add();
//	Else
//		NewLanguageRow = LanguagesRows[0];
//	EndIf;
//	
//	NewLanguageRow.Language = Language;
//	If AttributeName = Undefined Then
//		If ObjectsExtensionsAtServer.IsDocumentAttribute("LongDescription", Object.Metadata()) Then
//			NewLanguageRow.Description = ?(Value = Undefined, Object["LongDescription"], Value);
//		Else
//			NewLanguageRow.Description = ?(Value = Undefined, Object["Description"], Value);
//		EndIf;
//	Else
//		NewLanguageRow.Description = ?(Value = Undefined, Object[AttributeName], Value);
//	EndIf;
//	
//EndProcedure

//Function GetItemDataPath(Item) Export
//	Return Item.DataPath;
//EndFunction

//Function GetCurrentLanguagesValue(Val ObjectStructure, Val SystemLanguage, Val CurrentDescription) Export
//	LanguagesStructure = New Structure;
//	LanguagesStructure.Insert(LanguagesModulesServerCached.GetSystemLanguage().Code, New Structure("Ref, Description", SystemLanguage, CurrentDescription));
//	LanguagesDescriptionTable = ObjectStructure.LanguagesDescription;
//	q = 1;
//	For Each Row In LanguagesDescriptionTable Do
//		If Not Row.Language = SystemLanguage Then
//			LanguagesStructure.Insert("_" + Format(q, "NG="), New Structure("Ref, Description", Row.Language, Row.Description));
//			q = q + 1;
//		EndIf;
//	EndDo;

//	Return LanguagesStructure;
//EndFunction

//Function GetDescription(Object, Val Languages = Undefined) Export
//	ObjectMetadata = Object.Metadata();
//	If TypeOf(Languages) = Type("String") Then
//		Languages = Catalogs.Languages.FindByCode(Languages);
//		If ValueIsNotFilled(Languages) Then
//			Languages = Undefined;
//		EndIf;
//	EndIf;
//	SystemLanguage = LanguagesModulesServerCached.GetSystemLanguage();
//	If Languages = Undefined Then
//		Languages = SystemLanguage;
//	EndIf;
//	
//	ReturnDescription = "";
//	If ObjectsExtensionsAtServer.IsDocumentTabularPart("LanguagesDescription", ObjectMetadata) Then
//		FindRows = Object.LanguagesDescription.FindRows(New Structure("Language", Languages));
//		If FindRows.Count() = 0 Then
//			FindRows = Object.LanguagesDescription.FindRows(New Structure("Language", SystemLanguage));
//			If FindRows.Count() > 0 Then
//				ReturnDescription = FindRows[0].Description;
//			EndIf;
//		Else
//			ReturnDescription = FindRows[0].Description;
//		EndIf;
//	ElsIf ObjectsExtensionsAtServer.IsDocumentAttribute("LongDescription", ObjectMetadata) Then
//		ReturnDescription = Object.LongDescription;
//	ElsIf ObjectsExtensionsAtServer.IsDocumentAttribute("Description", ObjectMetadata) Then
//		ReturnDescription = Object.Description;
//	EndIf;
//	
//	Return ReturnDescription;
//EndFunction

//Procedure RefillDescription(ObjectMetadataFullName) Export
//	ObjectManager = FormsAtServer.GetObjectManager(ObjectMetadataFullName);
//	
//	MultiLanguageDescription = ObjectManager.GetTemplate("MultiLanguageDescription");
//	
//	ArrayLanguages = New Array;
//	ArrayLanguages.Add(Catalogs.Languages.English);
//	ArrayLanguages.Add(Catalogs.Languages.Russian);
//	ArrayLanguages.Add(Catalogs.Languages.Polish);
//	
//	NationalLanguage = Constants.NationalLanguage.Get();
//	For i = 1 To MultiLanguageDescription.LineCount() Do
//		TextDescription = StrReplace(MultiLanguageDescription.GetLine(i), """", "");
//		SysDescription = NStr(TextDescription, "Sys");
//		Try
//			ObjectRef = ObjectManager[SysDescription];
//			Object = ObjectRef.GetObject();
//			Object.LanguagesDescription.Clear();
//		Except
//			Continue;
//		EndTry;
//		For Each Language In ArrayLanguages Do
//			
//			If Language = NationalLanguage Then
//				Object.Description = NStr(TextDescription, Language.Code);
//			Else
//				RowLanguage = Object.LanguagesDescription.Add();
//				RowLanguage.Language = Language;
//				RowLanguage.Description = NStr(TextDescription, Language.Code);
//			EndIf;
//		EndDo;
//		
//		Object.DataExchange.Load = True;
//		Object.Write();
//	EndDo;
//EndProcedure

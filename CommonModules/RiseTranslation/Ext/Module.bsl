

Function InInterfaceFileLanguage(lang1, lang2)
	Return ?(Constants.RiseInterfaceFileLanguage.Get() = "ru", lang1, lang2);
EndFunction

//Function RiseStrSplit(String, Separator, IncludeBlank)
//	strTemp = StrReplace(String, Separator, Chars.LF);
//	arResult = New Array;
//	Для rowNumber = 1 По StrLineCount(strTemp) Do
//		item = StrGetLine(strTemp, rowNumber);
//		If Not IsBlankString(item) Or IncludeBlank Then
//			arResult.Add(item);
//		EndIf;
//	EndDo;
//	Return arResult;
//EndFunction

Procedure TreeTraversal(Form, Root, vtrRoot, vtFormItemsTranslation, vtToTranslation, Val fDynamicList = False, ElementType = "Item")
	type = TypeOf(Root);
	
	If type = Type("ManagedForm") Then
		arMDNameParts = StrSplit(Form.FormName, ".", True);
		If arMDNameParts.Count() = 4 And arMDNameParts[2] = InInterfaceFileLanguage("Форма", "Form") Then
			
			vtrMD = vtrRoot.Rows.Add();
			vtrMD.ElementType = "MD";
			vtrMD.Name = InInterfaceFileLanguage("Метаданные", "Metadata");
			
			MDType = arMDNameParts[0];
			
			vtAttributes = New ValueTable;
			vtAttributes.Columns.Add("Name");
			vtAttributes.Columns.Add("Arrange", New TypeDescription("String",,,, New StringQualifiers(1000)));
			
			attr = vtAttributes.Add();
			attr.Name = InInterfaceFileLanguage("Синоним", "Synonym");
			attr.Arrange = arMDNameParts[0] + arMDNameParts[1] + attr.Name;
			
			If MDType = InInterfaceFileLanguage("Документ", "Document") Or MDType = InInterfaceFileLanguage("Справочник", "Catalog") Then
				attr = vtAttributes.Add();
				attr.Name = InInterfaceFileLanguage("Представление объекта", "Object presentation");
				attr.Arrange = arMDNameParts[0] + arMDNameParts[1] + attr.Name;
				
				attr = vtAttributes.Add();
				attr.Name = InInterfaceFileLanguage("Расширенное представление объекта", "Extended object presentation");
				attr.Arrange = arMDNameParts[0] + arMDNameParts[1] + attr.Name;
				
				attr = vtAttributes.Add();
				attr.Name = InInterfaceFileLanguage("Представление списка", "List presentation");
				attr.Arrange = arMDNameParts[0] + arMDNameParts[1] + attr.Name;
				
				attr = vtAttributes.Add();
				attr.Name = InInterfaceFileLanguage("Расширенное представление списка", "Extended list presentation");
				attr.Arrange = arMDNameParts[0] + arMDNameParts[1] + attr.Name;
			ElsIf MDType = InInterfaceFileLanguage("Обработка", "DataProcessor") Then
				attr = vtAttributes.Add();
				attr.Name = InInterfaceFileLanguage("Расширенное представление", "Extended presentation");
				attr.Arrange = arMDNameParts[0] + arMDNameParts[1] + attr.Name;
			EndIf;
			
			attr = vtAttributes.Add();
			attr.Name = InInterfaceFileLanguage("Пояснение", "Explanation");
			attr.Arrange = arMDNameParts[0] + arMDNameParts[1] + attr.Name;
			
			vtTranslation = GetTranslationByArrangeList(vtAttributes.Copy(, "Arrange"));
			
			For each attr in vtAttributes Do
				vtrBranch = vtrMD.Rows.Add();
				vtrBranch.ElementType = "MD";
				vtrBranch.Name = attr.Name;
				vtrBranch.Arrange = attr.Arrange;
				GetFormItemTranslation(vtrBranch, vtTranslation);
			EndDo;
			
			//vtrBranch.Arrange = arMDNameParts[0] + arMDNameParts[1] + InInterfaceFileLanguage("Синоним", "Synonym");
			//Translation = GetTranslationByArrange(vtrBranch.Arrange);
			//vtrBranch.OriginalText = Translation.OriginalText;
			//vtrBranch.Translation = Translation.Translation;
			//vtrBranch.AdditionalLanguage = Translation.AdditionalLanguage;
			//vtrBranch.PreviousTranslation = vtrBranch.Translation;
			
			vtrBranch = vtrMD.Rows.Add();
			vtrBranch.ElementType = "MD";
			vtrBranch.Name = "Form name";
			vtrBranch.Arrange = StrReplace(Form.FormName, ".", "") + InInterfaceFileLanguage("Синоним", "Synonym");
			GetFormItemTranslation(vtrBranch, vtFormItemsTranslation);
			
			vtrBranch = vtrMD.Rows.Add();
			vtrBranch.ElementType = "MD";
			vtrBranch.Name = "Form title";
			vtrBranch.Arrange = StrReplace(Form.FormName, ".", "") + InInterfaceFileLanguage("ФормаЭлементФормаЗаголовок", "FormElementFormTitle");
			GetFormItemTranslation(vtrBranch, vtFormItemsTranslation);
			
		EndIf; 
	EndIf; 
	
	If type = Type("FormField") Or type = Type("FormTable") Or type = Type("FormDecoration") Then 
		contextManu = Root.ContextMenu;
		If contextManu.ChildItems.Count() > 0 Then
			vtrBranch = vtrRoot.Rows.Add();
			vtrBranch.Name = "<ContextMenu>";
			vtrBranch.ElementType = "ContextMenu";
			TreeTraversal(Form, contextManu, vtrBranch, vtFormItemsTranslation, vtToTranslation, fDynamicList, "ContextMenu");
			If vtrBranch.Rows.Count() = 0 Then
				vtrRoot.Rows.Delete(vtrBranch);
			EndIf;
		EndIf;
	EndIf;
	
	If type = Type("FormTable") Or type = Type("ManagedForm") Then 
		commandBar = Root.CommandBar;
		If commandBar.ChildItems.Count() > 0 Then
			vtrBranch = vtrRoot.Rows.Add();
			vtrBranch.Name = "<CommandBar>";
			vtrBranch.ElementType = "CommandBar";
			TreeTraversal(Form, commandBar, vtrBranch, vtFormItemsTranslation, vtToTranslation, fDynamicList, "CommandBar");
			If vtrBranch.Rows.Count() = 0 Then
				vtrRoot.Rows.Delete(vtrBranch);
			EndIf;
		EndIf;
	EndIf;
	
	If type = Type("ManagedForm") Or
		 type = Type("FormGroup") Or
		 type = Type("FormTable") Then
		 
		ChildItems = Root.ChildItems;
	Else
		ChildItems = New Array;
	EndIf;
		
	For each ChildItem из ChildItems Do
		If TypeOf(ChildItem) = Type("FormButton") And IsBlankString(ChildItem.CommandName) Then
			Continue;
		EndIf;
		vtrBranch = vtrRoot.Rows.Add();
		vtrBranch.ElementType = ElementType;
		
		If Not fDynamicList Then
			If TypeOf(ChildItem) = Type("FormTable") Then
				If Find(ChildItem.DataPath, ".") = 0 Then
					If TypeOf(Form[ChildItem.DataPath]) = Type("DynamicList") Then
						fDynamicList = True;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		FillRow(Form, ChildItem, vtrBranch, fDynamicList, vtFormItemsTranslation, vtToTranslation);
		
		TreeTraversal(Form, ChildItem, vtrBranch, vtFormItemsTranslation, vtToTranslation, fDynamicList, ElementType);
		vtrBranch.PreviousTranslation = vtrBranch.Translation;
		If TypeOf(ChildItem) = Type("FormGroup") And ElementType <> "Item" And vtrBranch.Rows.Count() = 0 Then
			vtrRoot.Rows.Delete(vtrBranch);
		EndIf;
	EndDo;
EndProcedure

Function GetTableName(text, Val pos, GetFullName = True)
	Name = "";
	strDelimeters = ", ()	" + Chars.LF;
	While True Do
		pos = pos - 1;
		If pos = 0 Then
			Return Name;
		EndIf;
		
		char = Mid(text, pos, 1);
		If Not GetFullName And char = "." Then
			Name = "";
		ElsIf Find(strDelimeters, char) > 0 Then
			Return Name;
		Else
			Name = char + Name;
		EndIf;
	EndDo; 
EndFunction

Procedure FillRow(Form, ChildItem, stItem, fDynamicList, vtFormItemsTranslation, vtToTranslation)
	
	FillPropertyValues(stItem, ChildItem);
	
	DataPath = stItem.DataPath;
	
	stItem.Arrange = StrReplace(Form.FormName, ".", "") + InInterfaceFileLanguage("ФормаЭлемент", "FormElement") + stItem.Name + "Title";
	
	If GetFormItemTranslation(stItem, vtFormItemsTranslation) Then
		Return;
	EndIf;
	
	If Not IsBlankString(DataPath) And Find(DataPath, ".") = 0 Then
		stItem.Arrange = StrReplace(Form.FormName, ".", "") + InInterfaceFileLanguage("ФормаРеквизит", "FormAttribute") + stItem.Name + "Title";
		
		If GetFormItemTranslation(stItem, vtFormItemsTranslation) Then
			Return;
		EndIf;
	EndIf;
	
	If TypeOf(ChildItem) = Type("FormButton") And Not IsBlankString(ChildItem.ИмяКоманды) Then
		stItem.Arrange = StrReplace(Form.FormName, ".", "") + InInterfaceFileLanguage("ФормаКоманда", "FormCommand") + ChildItem.ИмяКоманды + "Title";
		If Not GetFormItemTranslation(stItem, vtFormItemsTranslation) Then
			stItem.Arrange = "Command?";
		EndIf;
		Return;
	EndIf;
	
	If IsBlankString(DataPath) Then
		Return;
	EndIf;
	
	strDelimeters = ", 	" + Chars.LF;
	
	If fDynamicList Then
		pos = Find(DataPath, ".");
		If pos = 0 Then
			Return;
		EndIf;
		
		ParentDataPath = Left(DataPath, pos - 1);
		attribute = Form[ParentDataPath];
		
		If TypeOf(attribute) = Type("DynamicList") Then
			
			DataPath = StrReplace(DataPath, ParentDataPath + ".", "");
			
			If attribute.CustomQuery Then
				text = attribute.QueryText;
				arTemp = StrSplit(stItem.DataPath, ".", False);
				fieldName = arTemp[arTemp.UBound()];
				strAS = InInterfaceFileLanguage(" КАК ", " AS ");
				strAlias = strAS + fieldName;
				pos = Find(text, strAlias);
				If pos > 0 And Find(strDelimeters, Mid(text, pos + StrLen(strAlias), 1)) > 0 And Find(text, "." + fieldName + strAlias) = 0 Then
					stItem.DataPath = "<Alias>";
					Return;
				ElsIf Find(text, "." + fieldName) > 0 Then
					pos = Find(text, "." + fieldName);
					tab = GetTableName(text, pos, True);
					If StrOccurrenceCount(tab, ".") > 1 Then
						stItem.DataPath = tab;
						Return;
					EndIf;
					tab = GetTableName(text, pos, False);
					
					While Not IsBlankString(tab) And Find(tab, ".") = 0 Do
						If Find(text, strAS + tab) > 0 Then
							pos = Find(text, strAS + tab);
							tab = GetTableName(text, pos, True);
						Else
							Return;
						EndIf;
					EndDo;
					
					If Not IsBlankString(tab) Then
						strMD = tab;
					EndIf;
					
				EndIf;
			EndIf;
			
			If IsBlankString(strMD) Then
				If Not IsBlankString(attribute.MainTable) Then
					strMD = attribute.MainTable;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	If IsBlankString(strMD) Then
		strMD = Form.FormName;
	EndIf;
	
	strMD = StrReplace(strMD, ".", Chars.LF);
	If StrLineCount(strMD) < 2 Then
		Return;
	EndIf;
	
	stMD = New Structure;
	If SessionParameters.RiseSourceLanguage = "ru" Then
		stMD.Insert("Справочник", "Справочники");
		stMD.Insert("Документ", "Документы");
		stMD.Insert("РегистрСведений", "РегистрыСведений");
		stMD.Insert("РегистрНакопления", "РегистрыНакопления");
		stMD.Insert("РегистрБухгалтерии", "РегистрыБухгалтерии");
	Else
		stMD.Insert("Catalog", "Catalogs");
		stMD.Insert("Document", "Documents");
		stMD.Insert("InformationRegister", "InformationRegisters");
		stMD.Insert("AccumulationRegister", "AccumulationRegisters");
		stMD.Insert("AccountingRegister", "AccountingRegisters");
	EndIf;
	
	objectTypeSingular = StrGetLine(strMD, 1);
	objectName = StrGetLine(strMD, 2);
	
	If stMD.Property(objectTypeSingular) Then
		objectType = stMD[objectTypeSingular];
	Else
		Return;
	EndIf;
	
	md = Metadata[objectType][objectName];
	
	strPathPart = StrReplace(stItem.DataPath, InInterfaceFileLanguage("Объект.", "Object."), "");
	strPathPart = StrReplace(strPathPart, ".", Chars.LF);
	
	Arrange = objectTypeSingular + objectName;
	//strMDName = objectType + "." + objectName;
	Synonym = "";
	Для rowNumber = 1 По StrLineCount(strPathPart) Do
		curPathPart = StrGetLine(strPathPart, rowNumber);
		
		For each mdAttr Из md.StandardAttributes Do
			If mdAttr.Name = curPathPart Then
				stItem.Synonym = "<Standard>";
				stItem.Arrange = "";
				Return;
			EndIf;
		EndDo;
		
		If Find(objectType, InInterfaceFileLanguage("Регистр", "Register")) > 0 Then
			mdAttr = md.Dimensions.Find(curPathPart);
			If mdAttr <> Undefined Then
				Synonym = mdAttr.Synonym;
				Arrange = Arrange + InInterfaceFileLanguage("Измерение", "Dimension") + mdAttr.Name;
				//strMDName = strMDName + ".Dimensions." + mdAttr.Name;
				Break;
			EndIf;
			
			mdAttr = md.Resources.Find(curPathPart);
			If mdAttr <> Undefined Then
				Synonym = mdAttr.Synonym;
				Arrange = Arrange + InInterfaceFileLanguage("Ресурс", "Resource") + mdAttr.Name;
				//strMDName = strMDName + ".Resources." + mdAttr.Name;
				Break;
			EndIf;
		EndIf;
		
		mdAttr = md.Attributes.Find(curPathPart);
		If mdAttr <> Undefined Then
			Synonym = mdAttr.Synonym;
			Arrange = Arrange + InInterfaceFileLanguage("Реквизит", "Attribute") + mdAttr.Name;
			//strMDName = strMDName + ".Attributes." + mdAttr.Name;
			Break;
		EndIf;
		
		mdTS = Undefined;
		Try
			mdTS = md.TabularSections.Find(curPathPart);
		Except
		EndTry;
			
		If mdTS <> Undefined Then
			If rowNumber = StrLineCount(strPathPart) Then
				Synonym = mdTS.Synonym;
			EndIf;
			Arrange = Arrange + InInterfaceFileLanguage("ТабличнаяЧасть", "TabularSection") + mdTS.Name;
			//strMDName = strMDName + ".TabularSections." + mdTS.Name;
			
			md = mdTS;
			Continue;
		EndIf;
		
	EndDo;
	
	If IsBlankString(stItem.Title) Then
		stItem.Arrange = Arrange + InInterfaceFileLanguage("Синоним", "Synonym");
	EndIf;
	
	stItem.Synonym = Synonym;
	
	vtToTranslation.Add().Arrange = stItem.Arrange;
	
EndProcedure

Function GetFormItemTranslation(stItem, vtFormItemsTranslation)
	translation = vtFormItemsTranslation.Find(stItem.Arrange, "Arrange");
	If translation <> Undefined Then
		stItem.OriginalText = translation.OriginalText;
		stItem.Translation = translation.Translation;
		stItem.PreviousTranslation = translation.Translation;
		stItem.AdditionalLanguage = translation.AdditionalLanguage;
		Return True;
	EndIf;
	Return False;
EndFunction

Function GetFormInterface(Form) Export
	vtrForm = New ValueTree;
	vtrForm.Columns.Add("Name");
	vtrForm.Columns.Add("Title");
	vtrForm.Columns.Add("DataPath");
	vtrForm.Columns.Add("Arrange");
	vtrForm.Columns.Add("Synonym");
	vtrForm.Columns.Add("OriginalText");
	vtrForm.Columns.Add("Translation");
	vtrForm.Columns.Add("PreviousTranslation");
	vtrForm.Columns.Add("ElementType");
	vtrForm.Columns.Add("AdditionalLanguage");
	vtrForm.Columns.Add("PreviousAppearanceSettings");
	
	vtFormItemsTranslation = GetFormItemsTranslation(Form);
	vtToTranslation = New ValueTable;
	vtToTranslation.Columns.Add("Arrange", New TypeDescription("String",,,, New StringQualifiers(1000)));
	
	TreeTraversal(Form, Form, vtrForm, vtFormItemsTranslation, vtToTranslation);
	
	vtTranslation = GetTranslationByArrangeList(vtToTranslation);
	
	For each translation Из vtTranslation Do
		arRows = vtrForm.Rows.FindRows(New Structure("Arrange", translation.Arrange), True);
		If arRows.Count() > 0 Then
			If IsBlankString(translation.OriginalText) Then
				arRows[0].Arrange = "<Not found>";
			Else
				arRows[0].OriginalText = translation.OriginalText;
				arRows[0].Translation = translation.Translation;
				arRows[0].AdditionalLanguage = translation.AdditionalLanguage;
				arRows[0].PreviousTranslation = translation.Translation;
			EndIf;
		EndIf;
	EndDo;
	
	
	strAddress = PutToTempStorage(vtrForm, Form.UUID);
	Return strAddress;
EndFunction

Function GetFormItemsTranslation(Form)
	Arrange = StrReplace(Form.FormName, ".", "") + "%";
	
	Proxy = RiseConnection.GetProxy();
	Data = Proxy.GetByArrange(Arrange, SessionParameters.RiseSourceLanguage, SessionParameters.RiseTargetLanguage, SessionParameters.RiseAdditionalLanguage);
	
	Return XDTOSerializer.ReadXDTO(Data);
EndFunction

Function GetTranslationByArrangeList(vtToTranslation) Export
	Proxy = RiseConnection.GetProxy();
	Data = Proxy.GetByList(XDTOSerializer.WriteXDTO(vtToTranslation), SessionParameters.RiseSourceLanguage, SessionParameters.RiseTargetLanguage, SessionParameters.RiseAdditionalLanguage);
	
	Return XDTOSerializer.ReadXDTO(Data);
EndFunction

Function GetTranslationByArrange(Arrange) Export
	Proxy = RiseConnection.GetProxy();
	Data = Proxy.GetByArrange(Arrange, SessionParameters.RiseSourceLanguage, SessionParameters.RiseTargetLanguage, SessionParameters.RiseAdditionalLanguage);
	vtTranslations = XDTOSerializer.ReadXDTO(Data);
	If vtTranslations.Count() = 1 Then
		Return vtTranslations[0];
	EndIf; 
	
	Return New Structure("Arrange, OriginalText, Translation, AdditionalLanguage", Arrange, "", "", "");
EndFunction

Function SetTranslation(Arrange, Translation) Export
	Proxy = RiseConnection.GetProxy();
	Return Proxy.SetByArrange(Arrange, Translation, SessionParameters.RiseSourceLanguage, SessionParameters.RiseTargetLanguage);
	
EndFunction

Procedure SessionParametersSetting() Export
	
	//If Not IsInRole(Metadata.Roles.RiseTranslation) Then
	//	Return;
	//EndIf; 
	
	SetPrivilegedMode(True);
	
	Query = New Query("SELECT ALLOWED
	                  |	TranslatorsSettings.SettingValue AS SourceLanguage,
	                  |	"""" AS TargetLanguage,
	                  |	"""" AS AdditionalLanguage
	                  |INTO Temp
	                  |FROM
	                  |	InformationRegister.RiseTranslatorsSettings AS TranslatorsSettings
	                  |WHERE
	                  |	TranslatorsSettings.UserName = &UserName
	                  |	AND TranslatorsSettings.SettingName = ""SourceLanguage""
	                  |
	                  |UNION ALL
	                  |
	                  |SELECT
	                  |	"""",
	                  |	TranslatorsSettings.SettingValue,
	                  |	""""
	                  |FROM
	                  |	InformationRegister.RiseTranslatorsSettings AS TranslatorsSettings
	                  |WHERE
	                  |	TranslatorsSettings.UserName = &UserName
	                  |	AND TranslatorsSettings.SettingName = ""TargetLanguage""
	                  |
	                  |UNION ALL
	                  |
	                  |SELECT
	                  |	"""",
	                  |	"""",
	                  |	TranslatorsSettings.SettingValue
	                  |FROM
	                  |	InformationRegister.RiseTranslatorsSettings AS TranslatorsSettings
	                  |WHERE
	                  |	TranslatorsSettings.UserName = &UserName
	                  |	AND TranslatorsSettings.SettingName = ""AdditionalLanguage""
	                  |;
	                  |
	                  |////////////////////////////////////////////////////////////////////////////////
	                  |SELECT
	                  |	MAX(Temp.SourceLanguage) AS SourceLanguage,
	                  |	MAX(Temp.TargetLanguage) AS TargetLanguage,
	                  |	MAX(Temp.AdditionalLanguage) AS AdditionalLanguage
	                  |FROM
	                  |	Temp AS Temp");
	Query.SetParameter("UserName", InfoBaseUsers.CurrentUser().Name);
	sel = Query.Execute().Select();
	If sel.Next() Then
		SessionParameters.RiseSourceLanguage = String(sel.SourceLanguage);
		SessionParameters.RiseTargetLanguage = String(sel.TargetLanguage);
		SessionParameters.RiseAdditionalLanguage = String(sel.AdditionalLanguage);
	EndIf;
	
	If IsBlankString(SessionParameters.RiseSourceLanguage) Then
		SessionParameters.RiseSourceLanguage = "ru";
	EndIf;
	
	If IsBlankString(SessionParameters.RiseTargetLanguage) Then
		SessionParameters.RiseTargetLanguage = "en";
	EndIf;
	
	If IsBlankString(SessionParameters.RiseAdditionalLanguage) Then
		SessionParameters.RiseAdditionalLanguage = "";
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

Procedure ExportChangesToMXL(FileName, DateFrom = Undefined, SourceLanguage = "", TargetLanguage = "") Export
	If IsBlankString(SourceLanguage) Then
		SourceLanguage = SessionParameters.RiseSourceLanguage;
	EndIf; 
	
	If IsBlankString(TargetLanguage) Then
		TargetLanguage = SessionParameters.RiseTargetLanguage;
	EndIf; 
	
	Proxy = RiseConnection.GetProxy();
	If DateFrom = Undefined Then
		Data = Proxy.GetDictionary(SourceLanguage, TargetLanguage);
	Else
		Data = Proxy.GetRecentChanges(SourceLanguage, TargetLanguage, DateFrom);
	EndIf; 
	
	vtChanges = XDTOSerializer.ReadXDTO(Data);
	
	Document = New SpreadsheetDocument;
	
	SourceColumn = 1;
	TargetColumn = 2;
	
	Document.Area("R1C" + Format(SourceColumn, "NG=0")).Text = SourceLanguage;
	Document.Area("R1C" + Format(TargetColumn, "NG=0")).Text = TargetLanguage;
	
	RowI = 2;
	For each row in vtChanges Do
		Document.Area("R" + Format(RowI, "NG=0") + "C" + Format(SourceColumn, "NG=0")).Text = 
			row.OriginalText;
		Document.Area("R" + Format(RowI, "NG=0") + "C" + Format(TargetColumn, "NG=0")).Text = 
			row.Translation;
		RowI = RowI + 1;
	EndDo;

	Document.Write(FileName, SpreadsheetDocumentFileType.MXL);
	
EndProcedure

Function GetPrintListAtServer(PrintoutParameters, Parameters) Export
	ParametersForPrint = New Array;
	For Each Printout In PrintoutParameters.AvailablePrintouts Do
		If Printout.Use Then
			For Each PrintoutInfo In Parameters.DescriptionsList Do
				If PrintoutInfo.Description = Printout.Name Then
					ParametersForPrint.Add(PrintoutInfo);
					If Printout.Copies > 0 Then
						For Each StructureParaments In PrintoutInfo.StructureParamentsList Do
							StructureParaments.Copies = Printout.Copies;
						EndDo;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return ParametersForPrint;
EndFunction

Function GetPrintSettings(PrintParameters) Export
	RestoreSettings = CommonSettingsStorage.Load("PrintSettings_" + StrReplace(PrintParameters.OwnerFormName, ".", "_"),,,InfoBaseUsers.CurrentUser().Name);
	If RestoreSettings = Undefined Then
		RestoreSettings = New Structure("AvailablePrintoutsMap,DirectPrinting,HideThisWindow,PrintFileName, PrintOnPostAndClose", New Map, False, False, "", True);
	EndIf;
	AvailablePrintouts = New Array;
	
	For Each DescriptionPrintForm In PrintParameters.DescriptionsList Do
		AvailablePrintout = New Structure("Name", DescriptionPrintForm.Description);
		If RestoreSettings = Undefined Then 
			AvailablePrintouts.Add(AvailablePrintout);
			Continue;
		EndIf;
		Value = RestoreSettings.AvailablePrintoutsMap.Get(DescriptionPrintForm.Description);
		If Not Value = Undefined Then
			AvailablePrintout.Insert("Use", True);
			AvailablePrintout.Insert("Copies", Value);
			AvailablePrintouts.Add(AvailablePrintout);
		EndIf;
	EndDo;
	RestoreSettings.Insert("AvailablePrintouts", AvailablePrintouts);
	RestoreSettings.Insert("PrintList", GetPrintListAtServer(RestoreSettings, PrintParameters));
	RestoreSettings.Insert("DescriptionsList", PrintParameters.DescriptionsList);
	RestoreSettings.Insert("OwnerFormName", PrintParameters.OwnerFormName);
	Return RestoreSettings;
EndFunction

Function GetQueryTextForPrintoutObjects(ObjectFilter = Undefined, TypeArray = Undefined) Export
	TextResult = "";
	IsFirstLoop = True;
	MetadataArray = New Array;
	If TypeArray = Undefined Then
		For Each ObjectMetadata In Metadata.Catalogs Do
			MetadataArray.Add(New Structure("ObjectMetadata, MetadataType", ObjectMetadata, "Catalog"));
		EndDo;
		For Each ObjectMetadata In Metadata.Documents Do
			MetadataArray.Add(New Structure("ObjectMetadata, MetadataType", ObjectMetadata, "Document"));
		EndDo;
	Else
		For Each Type In TypeArray Do
			ObjectMetadata = Metadata.FindByType(Type);
			MetadataType = "";
			If Find(Upper(ObjectMetadata.FullName()), Upper("Catalog")) > 0 Then
				MetadataType = "Catalog";
			ElsIf Find(Upper(ObjectMetadata.FullName()), Upper("Document")) > 0 Then
				MetadataType = "Document";
			EndIf;
			If MetadataType = "" Then
				Continue;
			EndIf;
			
			MetadataArray.Add(New Structure("ObjectMetadata, MetadataType", ObjectMetadata, MetadataType));

		EndDo;
	EndIf;
	
	For Each MetadataInfo In MetadataArray Do
		ObjectMetadata = MetadataInfo.ObjectMetadata;
		If Not AccessParameters("Read", ObjectMetadata, "Ref").Accessibility Then
			Continue;
		EndIf;
		If Not IsFirstLoop Then
			TextResult = TextResult + "
			|UNION ALL
			|";
		EndIf; 
		TextResult = TextResult + "
		|SELECT " + ?(IsFirstLoop,"ALLOWED","") + "
		|	" + ObjectMetadata.Name + MetadataInfo.MetadataType +".Ref,";
		
		If MetadataInfo.MetadataType = "Document" Then
			TextResult = TextResult + "
			|" + ObjectMetadata.Name + MetadataInfo.MetadataType +".Posted";
		Else
			TextResult = TextResult + "
			|TRUE";
		EndIf;
		TextResult = TextResult + ?(IsFirstLoop, " AS Posted,", ",");
		 
		If CommonAtServer.IsDocumentAttribute("Customer", ObjectMetadata) Then
			TextResult = TextResult + "
			|" + ObjectMetadata.Name + MetadataInfo.MetadataType +".Customer";
			
		ElsIf CommonAtServer.IsDocumentAttribute("Supplier", ObjectMetadata) Then
			TextResult = TextResult + "
			|" + ObjectMetadata.Name + MetadataInfo.MetadataType +".Supplier";
		Else
			TextResult = TextResult + "
			|Undefined";
		EndIf;
		
		If IsFirstLoop Then
			TextResult = TextResult + " AS Partner,";
		Else
			TextResult = TextResult + ",";
		EndIf;
		
		If CommonAtServer.IsDocumentAttribute("Company", ObjectMetadata) Then
			TextResult = TextResult + "
			|" + ObjectMetadata.Name + MetadataInfo.MetadataType +".Company";
		Else
			TextResult = TextResult + "
			|VALUE(Catalog.Companies.EmptyRef)";
		EndIf;
		
		If IsFirstLoop Then
			TextResult = TextResult + " AS Company";
		EndIf;
		TextResult = TextResult + "
		|From " + MetadataInfo.MetadataType + "." + ObjectMetadata.Name + " As " + ObjectMetadata.Name + MetadataInfo.MetadataType;
		If Not ObjectFilter = Undefined Then
			TextResult = TextResult + "
			|WHERE " + ObjectMetadata.Name + MetadataInfo.MetadataType +"." + ObjectFilter + " 
			|";
		EndIf;
		IsFirstLoop = False;
	EndDo;

	Return TextResult;
EndFunction
	
Function GetAvailablePrintoutsList(Objects) Export
	TypeArray = New Array;
	For Each Object In Objects Do
		If TypeArray.Find(TypeOf(Object)) = Undefined Then
			TypeArray.Add(TypeOf(Object));
		EndIf;
	EndDo;
	TextQueryObjects = GetQueryTextForPrintoutObjects("Ref In (&ArrayRefs)", TypeArray);
	TextQueryObjects = Left(TextQueryObjects,Find(Upper(TextQueryObjects), "FROM ") - 1) + " INTO Docs " + Right(TextQueryObjects, StrLen(TextQueryObjects) - Find(Upper(TextQueryObjects), "FROM ")+1);
	Query = New Query;
	Query.Text = TextQueryObjects + "
	             |;
	             |
	             |////////////////////////////////////////////////////////////////////////////////
				 |SELECT
				 |	PrintoutsSettings.Object,
				 |	PrintoutsSettings.Description AS Description,
				 |	PrintoutsSettings.Company,
				 |	PrintoutsSettings.Partner,
				 |	PrintoutsSettings.Internal,
				 |	PrintoutsSettings.FileName,
				 |	PrintoutsSettings.Template,
				 |	PrintoutsSettings.Copies,
				 |	PrintoutsSettings.SavedParameters,
				 |	PrintoutsSettings.IsFiscal,
				 |	Docs.Ref,
				 |	0 + CASE
				 |		WHEN PrintoutsSettings.Company = VALUE(Catalog.Companies.EmptyRef)
				 |				OR PrintoutsSettings.Company = UNDEFINED
				 |			THEN 0
				 |		ELSE 1
				 |	END + CASE
				 |		WHEN PrintoutsSettings.Partner = VALUE(Catalog.Suppliers.EmptyRef)
				 |				OR PrintoutsSettings.Partner = VALUE(Catalog.Customers.EmptyRef)
				 |				OR PrintoutsSettings.Partner = UNDEFINED
				 |			THEN 0
				 |		ELSE 2
				 |	END AS CatalogPartnerFilling,
				 |	Docs.Posted
				 |INTO Base
				 |FROM
				 |	Docs AS Docs
				 |		LEFT JOIN InformationRegister.PrintoutsSettings AS PrintoutsSettings
				 |		ON (VALUETYPE(Docs.Ref) = VALUETYPE(PrintoutsSettings.Object))
				 |			AND (Docs.Company = PrintoutsSettings.Company
				 |				OR PrintoutsSettings.Company = VALUE(Catalog.Companies.EmptyRef)
				 |				OR PrintoutsSettings.Company = UNDEFINED)
				 |			AND (Docs.Partner = PrintoutsSettings.Partner
				 |				OR PrintoutsSettings.Partner = VALUE(Catalog.Customers.EmptyRef)
				 |				OR PrintoutsSettings.Partner = VALUE(Catalog.Suppliers.EmptyRef)
				 |				OR PrintoutsSettings.Partner = UNDEFINED)
				 |WHERE
				 |	PrintoutsSettings.PrintoutLanguage IN (&PrintoutLanguage)
				 |;
				 |
				 |////////////////////////////////////////////////////////////////////////////////
				 |SELECT
				 |	Base.Ref,
				 |	Base.Description,
				 |	MAX(Base.CatalogPartnerFilling) AS CatalogPartnerFilling,
				 |	Base.Posted
				 |INTO FormPrioritetPoints
				 |FROM
				 |	Base AS Base
				 |
				 |GROUP BY
				 |	Base.Ref,
				 |	Base.Description,
				 |	Base.Posted
				 |;
				 |
				 |////////////////////////////////////////////////////////////////////////////////
				 |SELECT
				 |	Base.Object AS Object,
				 |	Base.Description AS Description,
				 |	Base.Company AS Company,
				 |	Base.Partner AS Partner,
				 |	Base.Internal,
				 |	Base.FileName,
				 |	Base.Template,
				 |	Base.Copies,
				 |	Base.SavedParameters,
				 |	Base.IsFiscal,
				 |	Base.Ref,
				 |	Base.Posted
				 |FROM
				 |	Base AS Base
				 |		INNER JOIN FormPrioritetPoints AS FormPrioritetPoints
				 |		ON Base.Ref = FormPrioritetPoints.Ref
				 |			AND Base.Description = FormPrioritetPoints.Description
				 |			AND Base.CatalogPartnerFilling = FormPrioritetPoints.CatalogPartnerFilling
				 |TOTALS BY
				 |	Description,
				 |	Object,
				 |	Company,
				 |	Partner";
	
	Query.SetParameter("ArrayRefs", Objects);
	If Constants.UseMultiLanguagesDescriptions.Get() Then
		Query.Text = StrReplace(Query.Text, "PrintoutsSettings.PrintoutLanguage IN (&PrintoutLanguage)", "True");
	Else
		SysLeng = LanguagesModulesServerCached.GetSystemLanguage();
		PrintoutLanguage = New Array;
		PrintoutLanguage.Add(Upper(SysLeng.Code));
		PrintoutLanguage.Add(Lower(SysLeng.Code));
		PrintoutLanguage.Add("");
		Query.SetParameter("PrintoutLanguage", PrintoutLanguage);
	EndIf;
	Result = Query.Execute();
	SelectionDescription = Result.Select(QueryResultIteration.ByGroups);
	
	PrintoutsDescriptionList = New Array;
	While SelectionDescription.Next() Do
	    SelectionObject = SelectionDescription.Select(QueryResultIteration.ByGroups);
		ArrayStructureParaments = New Array;
		While SelectionObject.Next() Do
		    SelectionCompany = SelectionObject.Select(QueryResultIteration.ByGroups);
			IsDocument = Documents.AllRefsType().ContainsType(TypeOf(SelectionObject.Object));
			While SelectionCompany.Next() Do
			    SelectionPartner = SelectionCompany.Select(QueryResultIteration.ByGroups);
				While SelectionPartner.Next() Do
					StructureParaments = New Structure("Object,Description,Company,Partner,Internal,FileName,Template,Copies,SavedParameters,IsFiscal, ObjectRefsInfo,IsDocument");
					StructureParaments.ObjectRefsInfo = New Array;
					StructureParaments.IsDocument = IsDocument;
				    Selection = SelectionPartner.Select();
					While Selection.Next() Do
						If Selection.Internal Then
							If Metadata.DataProcessors.Find(Selection.FileName) = Undefined Then
								Continue;
							EndIf;
						EndIf;
						
						FillPropertyValues(StructureParaments, Selection);

						StructureParaments.ObjectRefsInfo.Add(New Structure("Ref, Posted", Selection.Ref, Selection.Posted));
					EndDo;
					If StructureParaments.ObjectRefsInfo.Count() > 0 Then
						ArrayStructureParaments.Add(StructureParaments);
					EndIf;
				EndDo;
			EndDo;
			If ArrayStructureParaments.Count() > 0 Then
				PrintoutsDescriptionList.Add(New Structure("Description, StructureParamentsList", SelectionDescription.Description, ArrayStructureParaments));
			EndIf;
		EndDo;                                                    
	EndDo;
	
	Return New Structure("DescriptionsList", PrintoutsDescriptionList);
	
EndFunction

Function GetParameters(Objects, FormName) Export
	Parameters = GetAvailablePrintoutsList(Objects);
	Parameters.Insert("OwnerFormName", FormName);
	Parameters = GetPrintSettings(Parameters);
	Return Parameters;
EndFunction
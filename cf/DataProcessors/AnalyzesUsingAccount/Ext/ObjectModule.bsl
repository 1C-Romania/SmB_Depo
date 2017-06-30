Var MapObjects Export;

Function CreateArrayRegisters()
	
	InfoRegisters = New Array;

	For Each InfoReg In Metadata.InformationRegisters Do

		If (Find(InfoReg.Name, "Bookkeeping") <> 1)
			Or(Find(InfoReg.Name, "Policy") > 0)
			Or(Not InfoReg.Dimensions.Count() = 1)
			Or(InfoReg.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate)Then
			
			Continue;
			
		EndIf;
		
		MetadataObject = Metadata.FindByType(InfoReg.Dimensions[0].Type.Types()[0]);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		
		//change for 8.2
		
		//FindInSubsystems = False;
		//For Each Subsystems In InfoReg.Subsystems Do
		//	If Subsystems = Metadata.Subsystems.GeneralLedger.Subsystems.AccountManagement Then
		//		FindInSubsystems = True;
		//		Break;
		//	EndIf;
		//EndDo;
		FindInSubsystems = True;
		
		MetadataTypObject = "";
		If FindInSubsystems Then
			If Not Metadata.Catalogs.Find(MetadataObject.Name) = Undefined Then
				MetadataTypObject = "Catalog";
			ElsIf Not Metadata.ChartsOfCharacteristicTypes.Find(MetadataObject.Name) = Undefined Then
				MetadataTypObject = "ChartOfCharacteristicTypes";
			ElsIf Not Metadata.ChartsOfAccounts.Find(MetadataObject.Name) = Undefined Then
				MetadataTypObject = "ChartOfAccounts";
			ElsIf Not Metadata.ChartsOfCalculationTypes.Find(MetadataObject.Name) = Undefined Then
				MetadataTypObject = "ChartOfCalculationTypes";
			Else
				Continue;
			EndIf;
			
			ArrayResources = New Array;
			
			For Each Resource In InfoReg.Resources Do
				ArrayResources.Add(Resource);
			EndDo;
			
			InfoRegisters.Add(New Structure("Metadata, MetadataObject, TypMetadataObject, Resources, TextQuery", InfoReg, MetadataObject, MetadataTypObject, ArrayResources, Undefined));
		EndIf;		

	EndDo;
	
	For Each InfoReg In Metadata.Documents.SetAccountingPolicy.RegisterRecords Do 
		
		HaveAccountType = False;
		
		ArrayResources = New Array;
		
		For Each Resource In InfoReg.Resources Do
			
			If Resource.Type = new TypeDescription("ChartOfAccountsRef.Bookkeeping") Then
				ArrayResources.Add(Resource);
				HaveAccountType = True;
			EndIf;
		EndDo;
		If HaveAccountType Then
			InfoRegisters.Add(New Structure("Metadata, MetadataObject, TypMetadataObject, Resources, TextQuery", InfoReg, Metadata.Documents.SetAccountingPolicy, "Document", ArrayResources, Undefined));
		EndIf;
	EndDo;
	
	ArrayResources = New Array;

	TextQuery = "SELECT
	            |	BookkeepingOperationsTemplates.Ref AS RefObject,
				|	"""" AS Period,
				|	BookkeepingOperationsTemplates.Ref.IsFolder as IsFolder,
				|	BookkeepingOperationsTemplates.Ref.DeletionMark as DeletionMark
	            |FROM
	            |	Catalog.BookkeepingOperationsTemplates AS BookkeepingOperationsTemplates
	            |		LEFT JOIN Catalog.BookkeepingOperationsTemplates.ExchangeRateDifferences AS BookkeepingOperationsTemplatesExchangeRateDifferences
	            |		ON BookkeepingOperationsTemplates.Ref = BookkeepingOperationsTemplatesExchangeRateDifferences.Ref
	            |		LEFT JOIN Catalog.BookkeepingOperationsTemplates.Parameters AS BookkeepingOperationsTemplatesParameters
	            |		ON BookkeepingOperationsTemplates.Ref = BookkeepingOperationsTemplatesParameters.Ref
	            |		LEFT JOIN Catalog.BookkeepingOperationsTemplates.PurchaseVATRecords AS BookkeepingOperationsTemplatesPurchaseVATRecords
	            |		ON BookkeepingOperationsTemplates.Ref = BookkeepingOperationsTemplatesPurchaseVATRecords.Ref
	            |		LEFT JOIN Catalog.BookkeepingOperationsTemplates.Records AS BookkeepingOperationsTemplatesRecords
	            |		ON BookkeepingOperationsTemplates.Ref = BookkeepingOperationsTemplatesRecords.Ref
	            |		LEFT JOIN Catalog.BookkeepingOperationsTemplates.SalesVATRecords AS BookkeepingOperationsTemplatesSalesVATRecords
	            |		ON BookkeepingOperationsTemplates.Ref = BookkeepingOperationsTemplatesSalesVATRecords.Ref
	            |";
				
	TextWhere = "WHERE ";
	If ValueIsFilled(Account) Then  
	
		//UUIDAccountText = String(Account.UUID());
		UUIDAccountText = ValueToStringInternal(Account);
		
		For Each Attribute In Metadata.Catalogs.BookkeepingOperationsTemplates.Attributes Do
			If Attribute.Type.ContainsType(Type("ChartOfAccountsRef.Bookkeeping")) Then
				TextWhere = TextWhere + " BookkeepingOperationsTemplates." + Attribute.Name + " = &Acc Or ";
			ElsIf Attribute.Type.ContainsType(Type("String")) Then
				If Attribute.Type.StringQualifiers.Length = 0 Then
					TextWhere = TextWhere + " BookkeepingOperationsTemplates." + Attribute.Name + " LIKE ""%%" + UUIDAccountText + "%%"" Or ";
				EndIf;
			EndIf;
		EndDo;
		
		For Each Table In Metadata.Catalogs.BookkeepingOperationsTemplates.TabularSections Do
			For Each Attribute In Table.Attributes Do
				If Attribute.Type.ContainsType(Type("ChartOfAccountsRef.Bookkeeping")) Then
					TextWhere = TextWhere + " BookkeepingOperationsTemplates" + Table.Name + "." + Attribute.Name + " = &Acc Or ";
				ElsIf Attribute.Type.ContainsType(Type("String")) Then
					If Attribute.Type.StringQualifiers.Length = 0 Then
						TextWhere = TextWhere + " BookkeepingOperationsTemplates" + Table.Name + "." + Attribute.Name + " LIKE ""%%" + UUIDAccountText + "%%"" Or ";
					EndIf;
				EndIf;
			EndDo;
		EndDo;
		
		TextWhere = Left(TextWhere, StrLen(TextWhere) - 4);
	EndIf;
	If StrLen(TextWhere) > 6 Then
		
		TextWhere = StrReplace(TextWhere,"""","""""");
		TextWhere = StrReplace(TextWhere,"""%%","%%");
		TextWhere = StrReplace(TextWhere,"%%""","%%");
		TextQuery = TextQuery + TextWhere;
		
	EndIf;
	TextQuery = TextQuery + "
			|TOTALS BY
			|	RefObject HIERARCHY";

	InfoRegisters.Add(New Structure("Metadata, MetadataObject, TypMetadataObject, Resources, TextQuery", Metadata.Catalogs.BookkeepingOperationsTemplates.TabularSections.Records, Metadata.Catalogs.BookkeepingOperationsTemplates, "Catalog", ArrayResources, TextQuery));
	
	Return InfoRegisters;
	
EndFunction

Function GetDataFromReg(InfoRegisters)
	
	TextQuery = "";
	For Each InfoRegister In InfoRegisters Do
		If InfoRegister.TextQuery = Undefined Then
			TextQuery = TextQuery + "SELECT" + Chars.LF;
			
			TextQuery = TextQuery + InfoRegister.MetadataObject.Name + ".Ref AS RefObject," + Chars.LF;
			TextQuery = TextQuery + InfoRegister.Metadata.Name + ".Period AS Period," + Chars.LF;
			TextQuery = TextQuery + ?(InfoRegister.TypMetadataObject = "Document", "False", ?(InfoRegister.MetadataObject.Hierarchical, InfoRegister.MetadataObject.Name + ".IsFolder", "False")) + " As IsFolder," + Chars.LF;
			TextQuery = TextQuery + InfoRegister.MetadataObject.Name + ".DeletionMark AS DeletionMark," + Chars.LF;
			
			TextQueryForTotal = "";
			StringWhere = "";
			
			For Each Resource In InfoRegister.Resources Do
				If Resource.Type.ContainsType(Type("ChartOfAccountsRef.Bookkeeping")) Then
					If ValueIsFilled(Account) Then
						StringWhere = StringWhere +?(StringWhere="",""," or ") + Resource.Name + " = &Acc";
					Else
						StringWhere = "";
					EndIf;
				EndIf;
				TextQuery = TextQuery + Chars.LF + InfoRegister.Metadata.Name + "." + Resource.Name + " AS " + Resource.Name + ",";
				If InfoRegister.TypMetadataObject = "Catalog" Then
					If InfoRegister.MetadataObject.Hierarchical Then
						TextQueryForTotal = TextQueryForTotal + "
						|	CASE
						|	WHEN IsFolder = TRUE
						|	THEN """"
						|	ELSE MAX(" + Resource.Name + ")
						|	END AS " + Resource.Name + ",";
					EndIf;
				EndIf;
			EndDo;
			If InfoRegister.TypMetadataObject = "Catalog" Then
				If InfoRegister.MetadataObject.Hierarchical Then
					TextQueryForTotal = TextQueryForTotal + "
					|	CASE
					|	WHEN IsFolder = TRUE
					|	THEN """"
					|	ELSE MAX(Period)
					|	END AS Period,";
					
					TextQueryForTotal = Left(TextQueryForTotal, StrLen(TextQueryForTotal) - 1);
				EndIf;
			EndIf;
			TextQuery = Left(TextQuery, StrLen(TextQuery) - 1);

			TextQuery = TextQuery + "
			|FROM
			|	" + InfoRegister.TypMetadataObject + "." + InfoRegister.MetadataObject.Name + " AS " + InfoRegister.MetadataObject.Name + "
			|		INNER JOIN InformationRegister." + InfoRegister.Metadata.Name + ".SliceLast(&Date, " + StringWhere + ") AS " + InfoRegister.Metadata.Name + "
			|		ON " + 
			
			InfoRegister.Metadata.Name + "." + ?(InfoRegister.TypMetadataObject = "Catalog", InfoRegister.Metadata.Dimensions[0].Name,"Recorder") + " = " + InfoRegister.MetadataObject.Name + ".Ref
			|";
			
			TextQuery = TextQuery + "
			|WHERE True";
			If InfoRegister.TypMetadataObject = "Catalog" Then
				If InfoRegister.MetadataObject.Hierarchical Then
					TextQuery = TextQuery + "
					|   And
					|	" + InfoRegister.MetadataObject.Name + ".IsFolder = FALSE";
				EndIf;

				TextQuery = TextQuery + ?(InfoRegister.MetadataObject.Hierarchical,"
				|TOTALS" + TextQueryForTotal + "
				|BY
				|	RefObject HIERARCHY","") + ";" + Chars.LF;
			Else
				TextQuery = TextQuery + ";" + Chars.LF;
			EndIf;
		Else
			TextQuery = TextQuery + InfoRegister.TextQuery + ";" + Chars.LF;
		EndIf;
	EndDo;
	Query = New Query;
	Query.SetParameter("Acc", Account);
	Query.SetParameter("Date",Date);
	Query.Text = TextQuery;
	Results = Query.ExecuteBatch();
	
	Return Results;
	
EndFunction

Function GetDataFromRegByAccount(Array)
	
	Query = New Query;
	Query.Text = "";

	MaxCountResources = 0;

	For Each Element In Array Do
		
		Query.Text = Query.Text + Chars.LF + "Select " + Chars.LF;
		Query.Text = Query.Text + Element.MetadataObject.Name + ".Ref AS RefObject," + Chars.LF;
		Query.Text = Query.Text + Element.Metadata.Name + ".Period AS Period," + Chars.LF;
		Query.Text = Query.Text + ?(Element.MetadataObject.Hierarchical, Element.MetadataObject.Name + ".IsFolder", "False") + " As IsFolder," + Chars.LF;
		Query.Text = Query.Text + Element.MetadataObject.Name + ".DeletionMark AS DeletionMark," + Chars.LF;
		
		CountResources = 0;
		StringWhere = "";
		For Each Resource In Element.Resources Do
			
			If Resource.Type.ContainsType(Type("ChartOfAccountsRef.Bookkeeping")) Then
				Query.Text = Query.Text + Element.Metadata.Name + "." + Resource.Name + " AS " + Resource.Name + ",";
				StringWhere = StringWhere +?(StringWhere="",""," or ") + Resource.Name + " = &Acc"; // Element.Metadata.Name + "." + 
				CountResources = CountResources + 1;
			EndIf;
			
		EndDo;
		
		Query.Text = Left(Query.Text, StrLen(Query.Text) - 1) + Chars.LF;
		
		If CountResources > MaxCountResources Then
			MaxCountResources = CountResources;
		EndIf;
		
		Query.Text = Query.Text + " From InformationRegister." + Element.Metadata.Name + ".SliceLast(&Date, " + StringWhere + ") As " + Element.Metadata.Name + Chars.LF;
		Query.Text = Query.Text + ";";
	EndDo;
	
	Query.Text = Left(Query.Text, StrLen(Query.Text) - 1);
	
	Query.SetParameter("Acc", Account);
	Query.SetParameter("Date",Date);
	
	ResultQuery = Query.ExecuteBatch();
	
	Return ResultQuery;
	
EndFunction

Function PrintTemplate() Export
	MapObjects = New Map;
	
	InfoRegisters = CreateArrayRegisters();
	
	Results = GetDataFromReg(InfoRegisters);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	Template = GetTemplate("Template");

	AreaPartName = Template.GetArea("PartName");
	
	AreaPic = Template.GetArea("Picture|Empty");

	AreaTitleEmpty = Template.GetArea("Title|Empty");
	
	AreaTitlePeriod = Template.GetArea("Title|Period");
	AreaTitleDimensionTitle = Template.GetArea("Title|DimensionTitle");
	AreaTitleDimension = Template.GetArea("Title|Dimension");
	AreaTitleResource = Template.GetArea("Title|Resource");
	
	AreaRowPeriod = Template.GetArea("Row|Period");
	AreaRowDimension = Template.GetArea("Row|Dimension");
	AreaRowResource = Template.GetArea("Row|Resource");

	Index = 0;
	
	For Each Result In Results Do
		
		StartNewFormatRow = SpreadsheetDocument.TableHeight + 1;
		
		InfoRegister = InfoRegisters[Index];
		Selection = Result.Select(QueryResultIteration.ByGroups);
		
		CountSelection = Selection.Count();
		If CountSelection = 0 Then
			Index = Index + 1;
			Continue;
		EndIf;
		
		AreaPartName.Parameters.RegisterName = InfoRegister.MetadataObject.Presentation();
		SpreadsheetDocument.Put(AreaPartName);
		
		SpreadsheetDocument.StartRowGroup();

		AreaTitleDimensionTitle.Parameters.Name = InfoRegister.MetadataObject.Presentation();

		SpreadsheetDocument.Put(AreaTitleDimensionTitle);
		
		If Not Results.Count() = Index + 1 Then
			SpreadsheetDocument.Join(AreaTitlePeriod);
		EndIf;
		
		For Each Resource In InfoRegister.Resources Do
			AreaTitleResource.Parameters.Name = Resource.Presentation();
			SpreadsheetDocument.Join(AreaTitleResource);
		EndDo;

		SpreadsheetDocument.StartRowAutoGrouping();
		
		
		While Selection.Next() Do
			
			If Selection.IsFolder AND Not Selection.DeletionMark Then
				AreaPic.Drawings.Pic.Picture = PictureLib.CatalogFolder;
			ElsIf Selection.IsFolder AND Selection.DeletionMark Then
				AreaPic.Drawings.Pic.Picture = PictureLib.CatalogFolderDeletionMarked;
			ElsIf Not Selection.IsFolder AND Not Selection.DeletionMark Then
				AreaPic.Drawings.Pic.Picture = PictureLib.CatalogItem;
			ElsIf Not Selection.IsFolder AND Selection.DeletionMark Then
				AreaPic.Drawings.Pic.Picture = PictureLib.CatalogItemDeletionMarked;
			EndIf;
			
			If Selection.Period = NULL Then
				ItsNew = True;
				Period = Date("19800101000000");
			Else
				ItsNew = False;
				Period = Selection.Period;
			EndIf;
			
			Object = Selection.RefObject;
			
			Cell = "RefObject";
			
			AreaPic.Areas.Pic.Left = 5 + 3 * Selection.Level();

			SpreadsheetDocument.Put(AreaPic, Selection.Level() + 1);

			MapObjects.Insert(Object, SpreadsheetDocument.TableHeight);
			
			#If ThickClientOrdinaryApplication Then
				AreaRowDimension.Parameters.Decipher = New Structure("Register, Period, Object, ItsNew, Cell", InfoRegister, Period, Object, ItsNew, Cell);
			#Else
				InfoRegisterPath = PutToTempStorage(InfoRegister, New UUID);
				ObjectPath = PutToTempStorage(Object, New UUID);
				AreaRowDimension.Parameters.Decipher = New Structure("Register, Period, Object, ItsNew, Cell", InfoRegisterPath, Period, ObjectPath, ItsNew, Cell);	
			#EndIf
				
			AreaRowDimension.Parameters.Value = Selection.RefObject;
			AreaRowDimension.CurrentArea.Indent = Selection.Level();
			
			SpreadsheetDocument.Join(AreaRowDimension);
			
			Cell = "Period";
			
			#If ThickClientOrdinaryApplication Then
				AreaRowPeriod.Parameters.Decipher = New Structure("Register, Period, Object, ItsNew, Cell", InfoRegister, Period, Object, ItsNew, Cell);	
			#Else
				AreaRowPeriod.Parameters.Decipher = New Structure("Register, Period, Object, ItsNew, Cell", InfoRegisterPath, Period, ObjectPath, ItsNew, Cell);
			#EndIf
			
			AreaRowPeriod.Parameters.Period = Selection.Period;

			If Not Results.Count() = Index + 1 Then
				SpreadsheetDocument.Join(AreaRowPeriod);
			EndIf;

			For Each Resource In InfoRegister.Resources Do
				Cell = Resource.Name;
				
				#If ThickClientOrdinaryApplication Then
					AreaRowResource.Parameters.Decipher = New Structure("Register, Period, Object, ItsNew, Cell", InfoRegister, Period, Object, ItsNew, Cell);
				#Else
					AreaRowResource.Parameters.Decipher = New Structure("Register, Period, Object, ItsNew, Cell", InfoRegisterPath, Period, ObjectPath, ItsNew, Cell);	
				#EndIf
				
				If ItsNew Then
					AreaRowResource.Parameters.Value = Undefined;
				Else
					AreaRowResource.Parameters.Value = Selection[Resource.Name];
				EndIf;
				SpreadsheetDocument.Join(AreaRowResource);
			EndDo;
		EndDo;
		SpreadsheetDocument.EndRowAutoGrouping();
		
		EndNewFormatColum = InfoRegister.Resources.Count() + 3;
		EndNewFormatRow = SpreadsheetDocument.TableHeight;
		AreaNewFormat = SpreadsheetDocument.Area(StartNewFormatRow, 1, EndNewFormatRow, EndNewFormatColum);
		AreaNewFormat.CreateFormatOfRows();
		
		SpreadsheetDocument.EndRowGroup();
		
		Index = Index + 1;
		
	EndDo;

	Return SpreadsheetDocument;
	
EndFunction
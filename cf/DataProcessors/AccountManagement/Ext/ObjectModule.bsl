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
			
			InfoRegisters.Add(New Structure("Metadata, MetadataObject, TypMetadataObject, Resources", InfoReg, MetadataObject, MetadataTypObject, ArrayResources));
		EndIf;		

	EndDo;
	
	Return InfoRegisters;
	
EndFunction

Function GetDataFromReg(InfoRegisters)
	
	TextQuery = "";
	For Each InfoRegister In InfoRegisters Do
		
		TextQuery = TextQuery + "SELECT" + Chars.LF;
		
		TextQuery = TextQuery + InfoRegister.MetadataObject.Name + ".Ref AS RefObject," + Chars.LF;
		TextQuery = TextQuery + InfoRegister.Metadata.Name + ".Period AS Period," + Chars.LF;
		TextQuery = TextQuery + ?(InfoRegister.MetadataObject.Hierarchical, InfoRegister.MetadataObject.Name + ".IsFolder", "False") + " As IsFolder," + Chars.LF;
		TextQuery = TextQuery + InfoRegister.MetadataObject.Name + ".DeletionMark AS DeletionMark," + Chars.LF;
		TextQueryForTotal = "";
		For Each Resource In InfoRegister.Resources Do
			TextQuery = TextQuery + Chars.LF + InfoRegister.Metadata.Name + "." + Resource.Name + " AS " + Resource.Name + ",";
			If InfoRegister.MetadataObject.Hierarchical Then
				TextQueryForTotal = TextQueryForTotal + "
				|	CASE
				|	WHEN IsFolder = TRUE
				|	THEN """"
				|	ELSE MAX(" + Resource.Name + ")
				|	END AS " + Resource.Name + ",";
			EndIf;
		EndDo;
		If InfoRegister.MetadataObject.Hierarchical Then
			TextQueryForTotal = TextQueryForTotal + "
			|	CASE
			|	WHEN IsFolder = TRUE
			|	THEN """"
			|	ELSE MAX(Period)
			|	END AS Period,";
			
			TextQueryForTotal = Left(TextQueryForTotal, StrLen(TextQueryForTotal) - 1);
		EndIf;
		
		TextQuery = Left(TextQuery, StrLen(TextQuery) - 1);

		TextQuery = TextQuery + "
		|FROM
		|	" + InfoRegister.TypMetadataObject + "." + InfoRegister.MetadataObject.Name + " AS " + InfoRegister.MetadataObject.Name + "
		|		LEFT JOIN InformationRegister." + InfoRegister.Metadata.Name + ".SliceLast AS " + InfoRegister.Metadata.Name + "
		|		ON " + InfoRegister.Metadata.Name + "." + InfoRegister.Metadata.Dimensions[0].Name + " = " + InfoRegister.MetadataObject.Name + ".Ref
		|";
		If InfoRegister.MetadataObject.Hierarchical Then
			TextQuery = TextQuery + "
			|WHERE
			|	" + InfoRegister.MetadataObject.Name + ".IsFolder = FALSE";
		EndIf;
		TextQuery = TextQuery + ?(InfoRegister.MetadataObject.Hierarchical,"
		|TOTALS" + TextQueryForTotal + "
		|BY
		|	RefObject HIERARCHY","") + ";" + Chars.LF;
	EndDo;
	
	Query = New Query;
	Query.Text = TextQuery;
	Results = Query.ExecuteBatch();
	
	Return Results;
	
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
		
		AreaPartName.Parameters.RegisterName = InfoRegister.MetadataObject.Presentation();
		SpreadsheetDocument.Put(AreaPartName);
		
		SpreadsheetDocument.StartRowGroup();

		AreaTitleDimensionTitle.Parameters.Name = InfoRegister.MetadataObject.Presentation();
		SpreadsheetDocument.Put(AreaTitleDimensionTitle);
		
		SpreadsheetDocument.Join(AreaTitlePeriod);
		
		For Each Resource In InfoRegister.Resources Do
			AreaTitleResource.Parameters.Name = Resource.Presentation();
			SpreadsheetDocument.Join(AreaTitleResource);
		EndDo;
		
		Selection = Result.Select(QueryResultIteration.ByGroups);
		
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
			MapObjects.Insert(Object,SpreadsheetDocument.TableHeight);
			
						
			AreaRowDimension.Parameters.Decipher = New Structure("Register, Period, Object, ItsNew, Cell", InfoRegister, Period, Object, ItsNew, Cell);
			  
			AreaRowDimension.Parameters.Value = Selection.RefObject;
			AreaRowDimension.CurrentArea.Indent = Selection.Level();
			
			SpreadsheetDocument.Join(AreaRowDimension);
			
			Cell = "Period";
			AreaRowPeriod.Parameters.Decipher = New Structure("Register, Period, Object, ItsNew, Cell", InfoRegister, Period, Object, ItsNew, Cell);
			
			AreaRowPeriod.Parameters.Period = Selection.Period;
			SpreadsheetDocument.Join(AreaRowPeriod);
			
			For Each Resource In InfoRegister.Resources Do
				Cell = Resource.Name;
				AreaRowResource.Parameters.Decipher = New Structure("Register, Period, Object, ItsNew, Cell", InfoRegister, Period, Object, ItsNew, Cell);
				
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
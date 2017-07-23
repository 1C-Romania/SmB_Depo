Var Serializer;
Var TableOfPredifined;
Var MapReplaceOfRef;

// Function start filling data for choisen country
// 
// Parameters:
//    FileName - string - 
//
Procedure PredefinedDataAtServer(Val FileName) Export
	
	File = New File(FileName);
	
	If File.Extension = ".fi" Then
		
		XMLReader = New FastInfosetReader;
		XMLReader.Read();
		XMLReader.OpenFile(FileName);
		
		XMLWriter = New XMLWriter;
		TempFileName = GetTempFileName("xml");
		XMLWriter.OpenFile(TempFileName, "UTF-8");
		
		While XMLReader.Read() Do
			
			XMLWriter.WriteCurrent(XMLReader);
			
		EndDo;
		
		XMLWriter.Close();
		
		FileName = TempFileName;
		
	EndIf;
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(FileName);
	If Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.StartElement
		OR XMLReader.LocalName <> "_1CV8DtUD"
		OR XMLReader.NamespaceURI <> "http://www.1c.ru/V8/1CV8DtUD/" Then
		
		Mess2UserBadFormat();
		Return;
		
	EndIf;
	
	If Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.StartElement
		OR XMLReader.LocalName <> "Data" Then
		
		Mess2UserBadFormat();
		Return;
		
	EndIf;
	
	LoadTableOfPredifined(XMLReader);
	ReplaceRefToPredefined(FileName);
	
	XMLReader.OpenFile(FileName);
	XMLReader.Read();
	XMLReader.Read();
	
	If Not XMLReader.Read() Then 
		
		Mess2UserBadFormat();
		Return;
		
	EndIf;
	
	InitializateSerializatorXDTOWithAnnotationTypes();
	
	While Serializer.CanReadXML(XMLReader) Do
		
		Try
			WriteValue = Serializer.ReadXML(XMLReader);
		Except
			Raise;
		EndTry;
		
		Try
			WriteValue.DataExchange.Load = True;
		Except
		EndTry;
		
		Try
			WriteValue.Write();
		Except
			
			ErrorText = ErrorDescription();
			
			Try
				TextForMessage = NStr("ru='При загрузке объекта %1(%2) возникла ошибка: %3';
									  |en='In loading process for Object %1(%2) raised error: %3'");
				TextForMessage = StrTemplate(TextForMessage, WriteValue, TypeOf(WriteValue), ErrorText);
			Except
				TextForMessage = NStr("ru='При загрузке данных возникла ошибка: %1';
									  |en='In loading data process raised error: %1'");
				TextForMessage = StrTemplate(TextForMessage, ErrorText);
			EndTry;
			
			CommonUseClientServer.MessageToUser(TextForMessage);
			
		EndTry;
		
	EndDo;
	
	If XMLReader.NodeType <> XMLNodeType.EndElement
		OR XMLReader.LocalName <> "Data" Then
		
		Mess2UserBadFormat();
		Return;
		
	EndIf;
	
	If Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.StartElement
		OR XMLReader.LocalName <> "PredefinedData" Then
		
		Mess2UserBadFormat();
		Return;
		
	EndIf;
	
	XMLReader.Skip();
	
	If Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.EndElement
		OR XMLReader.LocalName <> "_1CV8DtUD"
		OR XMLReader.NamespaceURI <> "http://www.1c.ru/V8/1CV8DtUD/" Then
		
		Mess2UserBadFormat();
		Return;
		
	EndIf;
	
	XMLReader.Close();
	
EndProcedure

/////////////////////////////////////////////////////////////////
// <Procedure description>
//
// Parameters:
//  <Parameter1>  - <Type.Subtype> - <parameter description>
//                  <parameter description continued>
//  <Parameter2>  - <Type.Subtype> - <parameter description>
//                  <parameter description continued>
//
Procedure Mess2UserBadFormat()

	CommonUseClientServer.MessageToUser(NStr("ru='Неверный формат файла выгрузки!'; 
					  						 |en='File format is wrong!'"));
	
EndProcedure // Mess2UserBadFormat()

#Region XMLLoad

Procedure InitializateTableOfPredifined()
	
	TableOfPredifined = New ValueTable;
	TableOfPredifined.Columns.Add("TableName");
	TableOfPredifined.Columns.Add("Ref");
	TableOfPredifined.Columns.Add("PredefinedDataName");
	
EndProcedure

Procedure LoadTableOfPredifined(XMLReader)
	
	XMLReader.Skip();
	XMLReader.Read();
	
	InitializateTableOfPredifined();
	TempRow = TableOfPredifined.Add();
	
	MapReplaceOfRef = New Map;
	
	While XMLReader.Read() Do
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			If XMLReader.LocalName <> "item" Then
				
				TempRow.TableName = XMLReader.LocalName;
				
				TextQuery = 
				"Select
				|	Table.Ref AS Ref
				|From
				|	" + TempRow.TableName + " AS Table
				|Where
				|	Table.PredefinedDataName = &PredefinedDataName";
				Query = New Query(TextQuery);
				
			Else
				While XMLReader.ReadAttribute() Do
					TempRow[XMLReader.LocalName] = XMLReader.Value;
				EndDo;
				
				Query.SetParameter("PredefinedDataName", TempRow.PredefinedDataName);
				
				QueryResult = Query.Execute();
				If Not QueryResult.IsEmpty() Then
					
					Selecter = QueryResult.Select();
					
					If Selecter.Count() = 1 Then
						
						Selecter.Next();
						
						RefInIB = XMLString(Selecter.Ref);
						RefInFile = TempRow.Ref;
						
						If RefInIB <> RefInFile Then
							
							XMLType = XMLTypeOfRef(Selecter.Ref);
							
							MapType = MapReplaceOfRef.Get(XMLType);
							
							If MapType = Undefined Then
								
								MapType = New Map;
								MapType.Insert(RefInFile, RefInIB);
								MapReplaceOfRef.Insert(XMLType, MapType);
								
							Else
								MapType.Insert(RefInFile, RefInIB);
							EndIf;
						EndIf;
					Else
						ExeptionText = NStr("ru='Обнаружено дублирование предопределенных элементов %1 в таблице %2!';
											|en='Predefined elements %1 are duplicated in table %2!'");
						ExeptionText = StrReplace(ExeptionText, "%1", TempRow.PredefinedDataName);
						ExeptionText = StrReplace(ExeptionText, "%2", TempRow.TableName);
						
						Raise ExeptionText;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	XMLReader.Close();
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////////
// Return the manager object name of the object metadata.
// Restriction: not handled-point routes business processes.
//
// Parameters:
// FullName - String - full name of metadata object. Example: "Catalogs.Organization."
//
// Return value:
// CatalogManager, DocumentManager.
// 
Function ObjectManagerByFullName(FullName)
	
	NameParts = StrSplit(FullName, ".");
	
	If NameParts.Count() >= 2 Then
		ClassOM = NameParts[0];
		NameOM = NameParts[1];
	EndIf;
	
	If ВРег(ClassOM) = "CATALOG" Then
		Manager = Catalogs;
	ElsIf ВРег(ClassOM) = "CHARTOFCHARACTERISTICTYPES" Then
		Manager = ChartsOfCharacteristicTypes;
	ElsIf ВРег(ClassOM) = "CHARTOFACCOUNTS" Then
		Manager = ChartsOfAccounts;
	ElsIf ВРег(ClassOM) = "CHARTOFCALCULATIONTYPES" Then
		Manager = ChartsOfCalculationTypes;
	EndIf;
	
	Return Manager[NameOM];
	
EndFunction

////////////////////////////////////////////////////
// Return XDTOSerializer with annotation type.
//
// Return value:
//	XDTOSerializer - Serializer.
//
Procedure InitializateSerializatorXDTOWithAnnotationTypes()
	
	TypeWithAnotationsRef = PredifinedTypeForUnload();
	
	If TypeWithAnotationsRef.Count() > 0 Then
		Factory = FactoryWithTypes(TypeWithAnotationsRef);
		Serializer = New XDTOSerializer(Factory);
	Else
		Serializer = XDTOSerializer;
	EndIf;
	
EndProcedure

Function PredifinedTypeForUnload()
	
	Types = New Array;
	
	For Each MetadataObject Из Metadata.Catalogs Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject Из Metadata.ChartsOfAccounts Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject Из Metadata.ChartsOfCharacteristicTypes Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject Из Metadata.ChartsOfCalculationTypes Do
		Types.Add(MetadataObject);
	EndDo;
	
	Return Types;
	
EndFunction

Function FactoryWithTypes(Val Types)
	
	SchemaSet = XDTOFactory.ExportXMLSchema("http://v8.1c.ru/8.1/data/enterprise/current-config");
	Schema = SchemaSet[0];
	Schema.UpdateDOMElement();
	
	SpecifiedTypes = New Map;
	For Each Type Из Types Do
		SpecifiedTypes.Insert(XMLTypeOfRef(Type), True);
	EndDo;
	
	NameSpace = New Map;
	NameSpace.Insert("xs", "http://www.w3.org/2001/XMLSchema");
	DOMNamespaceResolver = New DOMNamespaceResolver(NameSpace);
	TextXPath = "/xs:schema/xs:complexType/xs:sequence/xs:element[starts-with(@type,'tns:')]";
	
	Query = Schema.DOMDocument.CreateXPathExpression(TextXPath, DOMNamespaceResolver);
	Result = Query.Evaluate(Schema.DOMDocument);

	While True Do
		
		Node = Result.IterateNext();
		If Node = Undefined Then
			Break;
		EndIf;
		TypeAttribute = Node.Attributes.GetNamedItem("type");
		TypeWithoutNSPrefix = Mid(TypeAttribute.TextContent, StrLen("tns:") + 1);
		
		If SpecifiedTypes.Get(TypeWithoutNSPrefix) = Undefined Then
			Continue;
		EndIf;
		
		Node.SetAttribute("nillable", "true");
		Node.RemoveAttribute("type");
	EndDo;
	
	XMLWriter = New XMLWriter;
	SchemeFileName = GetTempFileName("xsd");
	XMLWriter.OpenFile(SchemeFileName);
	DOMWriter = New DOMWriter;
	DOMWriter.Write(Schema.DOMDocument, XMLWriter);
	XMLWriter.Close();
	
	Factory = CreateXDTOFactory(SchemeFileName);
	
	Try
		DeleteFiles(SchemeFileName);
	Except
	EndTry;
	
	Return Factory;
	
EndFunction

Function XMLTypeOfRef(Val Value)
	
	If TypeOf(Value) = Type("MetadataObject") Then
		MetadataObject = Value;
		ObjectManager = ObjectManagerByFullName(MetadataObject.FullName());
		Ref = ObjectManager.GetRef();
	Else
		MetadataObject = Value.Metadata();
		Ref = Value;
	EndIf;
	
	If ObjectFormsReferenceType(MetadataObject) Then
		
		Return XDTOSerializer.XMLTypeOf(Ref).TypeName;
		
	Else
		
		ExceptionText = NStr("ru='Ошибка при определении XMLТипа ссылки для объекта %1: объект не является ссылочным!';
							 |en='Error in definition XMLType reference for object %1: object is not reference!'");
		ExceptionText = StrReplace(ExceptionText, "%1", MetadataObject.FullName());
		
		Raise ExceptionText;
		
	EndIf;
	
EndFunction

// Function determines whether the passed metadata object reference type
//
Function ObjectFormsReferenceType(ObjectMD)
	
	If ObjectMD = Undefined Then
		Return False;
	EndIf;
	
	If Metadata.Catalogs.Contains(ObjectMD)
		OR Metadata.Documents.Contains(ObjectMD)
		OR Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMD)
		OR Metadata.ChartsOfAccounts.Contains(ObjectMD)
		OR Metadata.ChartsOfCalculationTypes.Contains(ObjectMD)
		OR Metadata.ExchangePlans.Contains(ObjectMD)
		OR Metadata.BusinessProcesses.Contains(ObjectMD)
		OR Metadata.Tasks.Contains(ObjectMD) Then
		Return True;
	EndIf;
	
	Return False;
EndFunction

Procedure ReplaceRefToPredefined(FileName)
	
	ReadFlow = New TextReader(FileName);
	
	TempFile = GetTempFileName("xml");
	
	WriteFlow = New TextWriter(TempFile);
	
	// Constans for parse text
	StartOfType = "xsi:type=""v8:";
	LengthStartOfType = StrLen(StartOfType);
	EndOfType = """>";
	LengthEndOfType = StrLen(EndOfType);
	
	SourceRow = ReadFlow.ReadLine();
	While SourceRow <> Undefined Do
		
		RemainsOfRow = Undefined;
		
		CurrentPosition = 1;
		TypePosition = Find(SourceRow, StartOfType);
		While TypePosition > 0 Do
			
			WriteFlow.Write(Mid(SourceRow, CurrentPosition, TypePosition - 1 + LengthStartOfType));
			
			RemainsOfRow = Mid(SourceRow, CurrentPosition + TypePosition + LengthStartOfType - 1);
			CurrentPosition = CurrentPosition + TypePosition + LengthStartOfType - 1;
			
			EndOfTypePosition = Find(RemainsOfRow, EndOfType);
			If EndOfTypePosition = 0 Then
				Break;
			EndIf;
			
			TypeName = Left(RemainsOfRow, EndOfTypePosition - 1);
			MapReplace = MapReplaceOfRef.Get(TypeName);
			If MapReplace = Undefined Then
				TypePosition = Find(RemainsOfRow, StartOfType);
				Continue;
			EndIf;
			
			WriteFlow.Write(TypeName);
			WriteFlow.Write(EndOfType);
			
			SourceRowXML = Mid(RemainsOfRow, EndOfTypePosition + LengthEndOfType, 36);
			
			FindRowXML = MapReplace.Get(SourceRowXML);
			
			If FindRowXML = Undefined Then
				WriteFlow.Write(SourceRowXML);
			Else
				WriteFlow.Write(FindRowXML);
			EndIf;
			
			CurrentPosition = CurrentPosition + EndOfTypePosition - 1 + LengthEndOfType + 36;
			RemainsOfRow = Mid(RemainsOfRow, EndOfTypePosition + LengthEndOfType + 36);
			TypePosition = Find(RemainsOfRow, StartOfType);
			
		EndDo;
		
		If RemainsOfRow <> Undefined Then
			WriteFlow.WriteLine(RemainsOfRow);
		Else
			WriteFlow.WriteLine(SourceRow);
		EndIf;
		
		SourceRow = ReadFlow.ReadLine();
		
	EndDo;
	
	ReadFlow.Close();
	WriteFlow.Close();
	
	FileName = TempFile;
	
EndProcedure

#EndRegion

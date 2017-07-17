////////////////////////////////////////////////////////////////////////////////
// The Data exchange subsystem
// Procedures and functions to export and import data to XML-schema.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

#Region ExchangeInitialization
// Adds a row to the conversion rules table and initializes a value in the Properties column.
// Used in the exchange manager module while filling the table of the object conversion rules.
//
// Parameters:
//  ConversionRules - values table.
//
// The
//  Row of the conversion rules table return value.
//
Function InitializeObjectConversionRule(ConversionRules) Export
	
	ConversionRule = ConversionRules.Add();
	ConversionRule.Properties = InitializePropertyTableForConversionRules();
	Return ConversionRule;
	
EndFunction

// Initializes the exchange components.
//
// Parameters:
//  ExchangeDirection - String (Send or Receive).
//
// Return
//  value Structure. Includes exchange components: exchange rules and exchange parameters.
//
Function InitializeExchangeComponents(ExchangeDirection) Export
	
	ExchangeComponents = New Structure("
		|ExchangeFormatVersion,
		|XMLSchema,
		|ExchangeManager,
		|CorrespondentMode");
		
	ExchangeComponents.Insert("ExchangeDirection", ExchangeDirection);
	ExchangeComponents.Insert("IsExchangeThroughExchangePlan", True);
	ExchangeComponents.Insert("ErrorFlag", False);
	ExchangeComponents.Insert("ErrorMessageString", "");
	ExchangeComponents.Insert("EventLogMonitorMessageKey", DataExchangeServer.EventLogMonitorMessageTextDataExchange());
	
	DataExchangeStatus = New Structure;
	DataExchangeStatus.Insert("InfobaseNode");
	DataExchangeStatus.Insert("ActionOnExchange");
	DataExchangeStatus.Insert("StartDate");
	DataExchangeStatus.Insert("EndDate");
	DataExchangeStatus.Insert("ExchangeProcessResult");
	
	ExchangeComponents.Insert("DataExchangeStatus", DataExchangeStatus);
	
	KeepDataProtocol = New Structure;
	KeepDataProtocol.Insert("DataLogFile", Undefined);
	KeepDataProtocol.Insert("OutputInInformationMessagesToProtocol", False);
	KeepDataProtocol.Insert("AppendDataToExchangeProtocol", True);
	ExchangeComponents.Insert("KeepDataProtocol", KeepDataProtocol);
	
	ExchangeComponents.Insert("UseTransactions", True);
	
	If ExchangeDirection = "sending" Then
		
		ExchangeComponents.Insert("ExportedObjects", New Array);
		ExchangeComponents.Insert("DumpedObjectsCounter", 0);
		ExchangeComponents.Insert("MatchRegistrationIfNeeded", New Map);
		ExchangeComponents.Insert("ExportedObjectsByRef", New Array);
		
		ExchangeComponents.Insert("ExportScript");
		
		ExchangeComponents.Insert("ObjectRegistrationRulesTable");
		ExchangeComponents.Insert("ExchangePlanNodeProperties");
		
	Else
		
		ExchangeComponents.Insert("IncomingMessageNumber");
		ExchangeComponents.Insert("MessageNumberReceivedByCorrespondent");
		
		ExchangeComponents.Insert("DataImportToInformationBaseMode", True);
		ExchangeComponents.Insert("CounterOfImportedObjects", 0);
		ExchangeComponents.Insert("ObjectsCountForTransactions", 0);
		
		DocumentsForDelayedPosting = New ValueTable;
		DocumentsForDelayedPosting.Columns.Add("DocumentRef");
		DocumentsForDelayedPosting.Columns.Add("DocumentDate",           New TypeDescription("Date"));
		DocumentsForDelayedPosting.Columns.Add("DocumentPostedSuccessfully", New TypeDescription("Boolean"));
		DocumentsForDelayedPosting.Columns.Add("IsCollision", New TypeDescription("Number"));
		ExchangeComponents.Insert("DocumentsForDelayedPosting", DocumentsForDelayedPosting);
		
		ImportedObjects = New ValueTable;
		ImportedObjects.Columns.Add("HandlerName");
		ImportedObjects.Columns.Add("Object");
		ImportedObjects.Columns.Add("Parameters");
		ExchangeComponents.Insert("ImportedObjects", ImportedObjects);
		
		ExchangeComponents.Insert("DataTableOfPackageHeader", PackageHeaderDataNewTable());
		ExchangeComponents.Insert("DataTablesOfExchangeMessage", New Map);
		
		ExchangeComponents.Insert("ObjectsForPostponedRecording", New Map);
		
	EndIf;
	
	Return ExchangeComponents;
	
EndFunction

// Initializes the values table with exchange rules and places them in ExchangeComponents.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//
Procedure InitializeExchangeRulesTables(ExchangeComponents) Export
	
	ExchangeDirection = ExchangeComponents.ExchangeDirection;
	XMLSchema = ExchangeComponents.XMLSchema;
	ExchangeManager = ExchangeComponents.ExchangeManager;
	
	// Initialize tables of exchange rules.
	ExchangeComponents.Insert("DataProcessingRules", DataProcessingRulesTable(XMLSchema, ExchangeManager, ExchangeDirection));
	ExchangeComponents.Insert("ObjectConversionRules", ConversionRulesTable(XMLSchema, ExchangeManager, ExchangeDirection));
	
	ExchangeComponents.Insert("PredefinedDataConversionRules",
		PredefinedDataConversionRulesTable(XMLSchema, ExchangeManager, ExchangeDirection));
	
	ExchangeComponents.Insert("ConversionParameters", ConversionParametersStructure(ExchangeManager));
	
EndProcedure

#EndRegion

#Region ProtocolIntroduction
// Creates an object to write an exchange protocol and puts it in ExchangeComponents.
//
// Parameters:
//  ExchangeComponents        - Structure - contains all rules and parameters of exchange
//  ExchangeProtocolFileName - String, contains full name of the protocol file.
//
Procedure ExchangeProtocolInitialization(ExchangeComponents, ExchangeProtocolFileName) Export
	
	ExchangeComponents.KeepDataProtocol.DataLogFile = Undefined;
	If Not IsBlankString(ExchangeProtocolFileName) Then
		
		// Try to write into file of the exchange protocol.
		Try
			ExchangeComponents.KeepDataProtocol.DataLogFile = New TextWriter(
				ExchangeProtocolFileName,
				TextEncoding.ANSI,,
				ExchangeComponents.KeepExchangeProtocol.AppendDataToExchangeProtocol);
		Except
			
			MessageString = NStr("en='An error occurred when attempting to write to data protocol file: %1. Error description: %2';ru='Ошибка при попытке записи в файл протокола данных: %1. Описание ошибки: %2'",
				CommonUseClientServer.MainLanguageCode());
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangeProtocolFileName, ErrorDescription());
			
			WriteLogEventDataExchange(MessageString, ExchangeComponents, EventLogLevel.Warning);
			
		EndTry;
		
	EndIf;
	
EndProcedure

// Ends writing to the exchange protocol.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//
Procedure FinishExchangeProtocolLogging(ExchangeComponents) Export
	
	If ExchangeComponents.KeepDataProtocol.DataLogFile <> Undefined Then
		
		ExchangeComponents.KeepDataProtocol.DataLogFile.Close();
		ExchangeComponents.KeepDataProtocol.DataLogFile = Undefined;
		
	EndIf;
	
EndProcedure

// Saves an execution protocol (or displays it) of the specified structure message.
//
// Parameters:
//  Code               - Number. Message code.
//  RecordStructure   - Structure. Structure of the protocol writing.
//  SetErrorFlag - If true, then - this error message. Display ErrorCheckBox.
// 
Function WriteInExecutionProtocol(ExchangeComponents,
									Code = "",
									RecordStructure=Undefined,
									SetErrorFlag=True,
									Level=0,
									Align=22,
									ForceWritingToExchangeLog = False) Export 

  DataLogFile = ExchangeComponents.KeepDataProtocol.DataLogFile;
	OutputInInformationMessagesToProtocol = ExchangeComponents.KeepDataProtocol.OutputInInformationMessagesToProtocol;
	
	Indent = "";
	For Ct = 0 To Level-1 Do
		Indent = Indent + Chars.Tab;
	EndDo; 
	
	If TypeOf(Code) = Type("Number") Then
		
		ErrorMessages = DataExchangereuse.ErrorMessages();
		
		Str = ErrorMessages[Code];
		
	Else
		
		Str = String(Code);
		
	EndIf;

	Str = Indent + Str;
	
	If RecordStructure <> Undefined Then
		
		For Each Field IN RecordStructure Do
			
			Value = Field.Value;
			If Value = Undefined Then
				Continue;
			EndIf; 
			Key = Field.Key;
			Str  = Str + Chars.LF + Indent + Chars.Tab
				+ StringFunctionsClientServer.SupplementString(Field.Key, Align) + " =  " + String(Value);
			
		EndDo;
		
	EndIf;
	
	TranslationLiteral = ?(IsBlankString(ExchangeComponents.ErrorMessageString), "", Chars.LF);
	ExchangeComponents.ErrorMessageString = ExchangeComponents.ErrorMessageString + TranslationLiteral + Str;
	
	If SetErrorFlag Then
		
		ExchangeComponents.ErrorFlag = True;
		If ExchangeComponents.DataExchangeStatus.ExchangeProcessResult = Undefined Then
			ExchangeComponents.DataExchangeStatus.ExchangeProcessResult = Enums.ExchangeExecutionResult.Error;
		EndIf;
		
	EndIf;
	
	If DataLogFile <> Undefined Then
		
		If SetErrorFlag Then
			
			DataLogFile.WriteLine(Chars.LF + "Error.");
			
		EndIf;
		
		If SetErrorFlag
			Or ForceWritingToExchangeLog
			Or OutputInInformationMessagesToProtocol Then
			
			DataLogFile.WriteLine(Chars.LF + ExchangeComponents.ErrorMessageString);
		
		EndIf;
		
	EndIf;
	
	If ExchangeProcessResultError(ExchangeComponents.DataExchangeStatus.ExchangeProcessResult) Then
		
		ELLevel = EventLogLevel.Error;
		
	ElsIf ExchangeProcessResultDoMessageBox(ExchangeComponents.DataExchangeStatus.ExchangeProcessResult) Then
		
		ELLevel = EventLogLevel.Warning;
		
	Else
		
		ELLevel = EventLogLevel.Information;
		
	EndIf;
	
	// Note event in the event log.
	WriteLogEventDataExchange(
		ExchangeComponents.ErrorMessageString,
		ExchangeComponents,
		ELLevel);
	
	Return ExchangeComponents.ErrorMessageString;
	
EndFunction

#EndRegion

#Region ExchangeRulesSearch
// Searches for the conversion rule of an object by name.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//  Name              - String, rule name.
//
// Returns:
//  Row of exchange rules table with a needed rule.
//
Function OCRByName(ExchangeComponents, Name) Export
	
	ConversionRule = ExchangeComponents.ObjectConversionRules.Find(Name, "OCRName");
	
	If ConversionRule = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Credit slip with name %1 is not found';ru='Не найдено ПКО с именем %1'"), Name);
			
	Else
		Return ConversionRule;
	EndIf;

EndFunction

#EndRegion

#Region DataSending
// Exports data according to the exchange rules and parameters.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//
Procedure ExecuteDataExport(ExchangeComponents) Export
	
	NodeForExchange = ExchangeComponents.CorrespondentNode;
	
	ExchangeComponents.ExchangeManager.BeforeConversion(ExchangeComponents);
	
	If ExchangeComponents.IsExchangeThroughExchangePlan Then
	
		SentNo = CommonUse.ObjectAttributeValue(NodeForExchange, "SentNo") + 1;
		
		Try
			RunDumpOfRegisteredData(ExchangeComponents, SentNo);
		Except
			WriteInExecutionProtocol(ExchangeComponents, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		// Assign a number of the sent message for objects exported by reference.
		If ExchangeComponents.ExportedObjectsByRef.Count() > 0 Then
			
			// Register objects exported by the reference on the current node.
			For Each Item IN ExchangeComponents.ExportedObjectsByRef Do
				
				ExchangePlans.RecordChanges(NodeForExchange, Item);
				
			EndDo;
			
			DataExchangeServer.SelectChanges(NodeForExchange, SentNo, ExchangeComponents.ExportedObjectsByRef);
			
		EndIf;
		
		BeginTransaction();
		Recipient = NodeForExchange.GetObject();
		Recipient.SentNo = SentNo;
		Recipient.AdditionalProperties.Insert("Import");
		Recipient.Write();
		CommitTransaction();
		
		UnlockDataForEdit(NodeForExchange);
		
	Else
		
		For Each String IN ExchangeComponents.ExportScript Do
			
			DataProcessorRule = DERByName(ExchangeComponents, String.DERName);
			
			Try
				DataSelection = DataSelection(ExchangeComponents, DataProcessorRule);
			Except
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Error of geting data selection algorithm.
		|DER name:
		|%1 Error description: %2';ru='Ошибка выполнения алгоритма получения выборки данных.
		|Имя
		|ПОД: %1 Описание ошибки: %2'"),
					DataProcessorRule.Name,
					DetailErrorDescription(ErrorInfo()));
			EndTry;
			
			For Each SelectionObject IN DataSelection Do
				ExportSelectionObject(ExchangeComponents, SelectionObject, DataProcessorRule);
			EndDo;
			
		EndDo;
		
	EndIf;
	
	ExchangeComponents.ExchangeManager.AfterConversion(ExchangeComponents);
	
	ExchangeComponents.ExchangeFile.WriteEndElement(); // Body
	ExchangeComponents.ExchangeFile.WriteEndElement(); // Message
	
EndProcedure

// Converts the structure with data into the XDTO object of the specified type according to the rules.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//  Source         - Structure - source of data which need to be converted into the XDTO object.
//  XDTOType          - String - object type or XDTO value type into which the data should be converted.
//  Receiver         - XDTODataObject - object, to which the result will be placed.
//  RefsFromObject  - Array - contains common list of exported by the objects references.
// 
Function XDTOObjectFromXDTOData(
		ExchangeComponents,
		Val Source,
		Val XDTOType = Undefined,
		Receiver = Undefined,
		RefsFromObject = Undefined) Export
	
	If RefsFromObject = Undefined Then
		RefsFromObject = New Array;
	EndIf;
	
	ConversionRules = ExchangeComponents.ObjectConversionRules;
	CorrespondentNode = ExchangeComponents.CorrespondentNode;
	
	If Receiver = Undefined Then
		Receiver = XDTOFactory.Create(XDTOType);
	EndIf;
	
	For Each Property IN XDTOType.Properties Do
		
		PropertyValue = Undefined;
		PropertyFound = False;
		
		If TypeOf(Source) = Type("Structure") Then
			PropertyFound = Source.Property(Property.Name, PropertyValue);
		ElsIf TypeOf(Source) = Type("ValueTableRow")
			AND Source.Owner().Columns.Find(Property.Name) <> Undefined Then
			PropertyFound = True;
			PropertyValue = Source[Property.Name];
		EndIf;
		
		PropertyType = Undefined;
		If TypeOf(Property.Type) = Type("XDTOValueType") Then
			PropertyType = "RegularProperty";
		ElsIf TypeOf(Property.Type) = Type("XDTOObjectType") Then
			
			If Property.Name = "AdditionalInfo" Then
				PropertyType = "AdditionalInfo";
			ElsIf IsObjectTable(Property) Then
				PropertyType = "Table";
			ElsIf Property.Name = "KeyProperties"
				Or Find(Property.Type.Name, "KeyProperties") > 0 Then
				PropertyType = "KeyProperties";
			Else
				If PropertyFound Then
					PropertyType = "CompoundTypeProperty";
				Else
					PropertyType = "CommonCompoundProperty";
				EndIf;
			EndIf;
			
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Unknown property type <%1>. Object type: %2';ru='Неизвестный тип свойства <%1>. Тип объекта: %2'"),
				Property.Name,
				String(XDTOType)
			);
		EndIf;
		
		If PropertyType = "CommonCompoundProperty" Then
			
			XDTODataValue = XDTOObjectFromXDTOData(ExchangeComponents, Source, Property.Type,, RefsFromObject);
			
		Else
			
			If Not PropertyFound Then
				Continue;
			EndIf;
			
			// Check for fullness
			If PropertyValue = Null
				Or Not ValueIsFilled(PropertyValue) Then
				
				If Property.Nillable Then
					Receiver[Property.Name] = Undefined;
				EndIf;
				
				Continue;
				
			EndIf;
			
			XDTODataValue = Undefined;
			If PropertyType = "KeyProperties" Then
				XDTODataValue = XDTOObjectFromXDTOData(ExchangeComponents, PropertyValue, Property.Type,,RefsFromObject);
			ElsIf PropertyType = "RegularProperty" Then
				
				If IsXDTORef(Property.Type) Then // Reference conversion
					
					XDTODataValue = ConvertRefToXDTO(ExchangeComponents, PropertyValue, Property.Type);
					
					If RefsFromObject.Find(PropertyValue) = Undefined Then
						RefsFromObject.Add(PropertyValue);
					EndIf;
					
				ElsIf Property.Type.Facets <> Undefined
					AND Property.Type.Facets.Enums <> Undefined
					AND Property.Type.Facets.Enums.Count() > 0 Then // Enumeration conversion
					XDTODataValue = ConvertEnumerationIntoXDTO(ExchangeComponents, PropertyValue, Property.Type);
				Else // Conversion of a regular value.
					XDTODataValue = XDTOFactory.Create(Property.Type, PropertyValue);
				EndIf;
				
			ElsIf PropertyType = "AdditionalInfo" Then
				XDTODataValue = XDTOSerializer.WriteXDTO(PropertyValue);
				
			ElsIf PropertyType = "Table" Then
				
				XDTODataValue = XDTOFactory.Create(Property.Type);
				
				TableType = Property.Type.Properties[0].Type;
				
				RowPropertyName = Property.Type.Properties[0].Name;
				
				For Each SourceRow IN PropertyValue Do
					
					ReceiverRow = XDTOObjectFromXDTOData(ExchangeComponents, SourceRow, TableType,,RefsFromObject);
					
					XDTODataValue[RowPropertyName].Add(ReceiverRow);
					
				EndDo;
				
			ElsIf PropertyType = "CompoundTypeProperty" Then
				
				For Each CompoundTypeProperty IN Property.Type.Properties Do
					
					CompoundXDTOValue = Undefined;
					If TypeOf(PropertyValue) = Type("Structure")
						AND PropertyValue.CompoundPropertyType = CompoundTypeProperty.Type Then
						
						// Property of a compound type which contains items of only the KeyProperties type.
						CompoundXDTOValue = XDTOObjectFromXDTOData(ExchangeComponents, PropertyValue, CompoundTypeProperty.Type,,RefsFromObject);
					// Compound type property, and value is simple
					ElsIf (TypeOf(PropertyValue) = Type("String")
						AND Find(CompoundTypeProperty.Type.Name,"string")>0)
						OR (TypeOf(PropertyValue) = Type("Number")
						AND Find(CompoundTypeProperty.Type.Name,"decimal")>0)
						OR (TypeOf(PropertyValue) = Type("Boolean")
						AND Find(CompoundTypeProperty.Type.Name,"Boolean")>0)
						OR (TypeOf(PropertyValue) = Type("Date")
						AND Find(CompoundTypeProperty.Type.Name,"date")>0) Then
						CompoundXDTOValue = PropertyValue;

					ElsIf TypeOf(PropertyValue) = Type("String")
						AND TypeOf(CompoundTypeProperty.Type) = Type("XDTOValueType")
						AND CompoundTypeProperty.Type.Facets <> Undefined Then
						If CompoundTypeProperty.Type.Facets.Count() = 0 Then
							CompoundXDTOValue = PropertyValue;
						Else
							
							For Each Facet IN CompoundTypeProperty.Type.Facets Do
								If Facet.Value = PropertyValue Then
									CompoundXDTOValue = PropertyValue;
									Break;
								EndIf;
							EndDo;
							
						EndIf;
					EndIf;
					
					If CompoundXDTOValue <> Undefined Then
						Break;
					EndIf;
					
				EndDo;
				
				// If the value is transferred with a type which is not supported in a format - don't pass.
				If CompoundXDTOValue = Undefined Then
					Continue;
				EndIf;
				
				XDTODataValue = XDTOFactory.Create(Property.Type);
				XDTODataValue.Set(CompoundTypeProperty, CompoundXDTOValue);
			EndIf;
			
		EndIf;
		
		Receiver[Property.Name] = XDTODataValue;
		
	EndDo;
	Return Receiver;
EndFunction


// Converts data of the infobase into a structure with data according to the rules.
//
// Parameters:
//  ExchangeComponents    - Structure - contains all rules and parameters of exchange
//  Source            - Reference to the exported object of the infobase.
//  ConversionRule  - Table row of the object conversion rules according
//                        to which it is converted.
//  ExportStack        - an array, contains references to the exported objects taking the inclusion into account.
//
Function XDTODataFromIBData(ExchangeComponents, Source, Val ConversionRule, ExportStack = Undefined) Export
	
	Receiver = New Structure;
	
	If ExportStack = Undefined Then
		ExportStack = New Array;
	EndIf;
	
	If ConversionRule.IsReferenceType Then
		
		If ExportStack.Find(Source.Ref) <> Undefined Then
			Return Undefined;
		Else
			ExportStack.Add(Source.Ref);
		EndIf;
	Else
		ExportStack.Add(Source);
	EndIf;
	
	If ConversionRule.ThisIsConstant Then
		
		If ConversionRule.XDTOType.Properties.Count() = 1 Then
			
			Receiver.Insert(ConversionRule.XDTOType.Properties[0].Name, Source.Value);
			
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='XML-Schema error. One property should be set for a receiver.
		|Source type:
		|%1 Receiver type: %2';ru='Ошибка XML-схемы. Для приемника должно быть задано одно свойство.
		|Тип
		|источника: %1 Тип приемника: %2'"),
				String(TypeOf(Source)),
				ConversionRule.XDTOType
				);
		EndIf;
		
	Else
		
		// Execute PCR, 1st stage
		For Each PCR IN ConversionRule.Properties Do
			
			If ConversionRule.ObjectData <> Undefined
				AND PCR.ConfigurationProperty = ""
				AND PCR.UsedConversionAlgorithm Then
				Continue;
			EndIf;
			
			If ExportStack.Count() > 1 AND Not PCR.KeyPropertiesProcessing Then
				Continue;
			EndIf;
			
			ExportProperty(
				ExchangeComponents,
				Source,
				Receiver,
				PCR,
				ExportStack,
				1);
		EndDo;
		
		// {Handler: OnSendData} Begin
		If ConversionRule.HasHandlerOnDataSend Then
			
			If Not Receiver.Property("KeyProperties") Then
				Receiver.Insert("KeyProperties", New Structure);
			EndIf;
			
			OnDataSending(Source, Receiver, ConversionRule.OnDataSending, ExchangeComponents, ExportStack);
			
			If ExportStack.Count() > 1 Then
				For Each KeyProperty IN Receiver.KeyProperties Do
					Receiver.Insert(KeyProperty.Key, KeyProperty.Value);
				EndDo;
				Receiver.Delete("KeyProperties");
			EndIf;
			
			// Execute PCR, 2nd stage
			For Each PCR IN ConversionRule.Properties Do
				If PCR.FormatProperty = "" 
					OR (ExportStack.Count() > 1 AND Not PCR.KeyPropertiesProcessing) Then
					Continue;
				EndIf;
				
				// Convert if the property has instruction.
				If ExportStack.Count() = 1 AND PCR.KeyPropertiesProcessing Then
					PropertyValue = Receiver.KeyProperties[PCR.FormatProperty];
				Else
					PropertyValue = Receiver[PCR.FormatProperty];
				EndIf;
				
				If PCR.UsedConversionAlgorithm Then
					
					If TypeOf(PropertyValue) = Type("Structure")
						AND PropertyValue.Property("Value")
						AND PropertyValue.Property("OCRName")
						Or PCR.PropertyConversionRule <> ""
						AND TypeOf(PropertyValue) <> Type("Structure") Then
						
						ExportProperty(
							ExchangeComponents,
							Source,
							Receiver,
							PCR,
							ExportStack,
							2);
							
					EndIf;
						
				EndIf;
			EndDo;
			
			// Execute PCR for TP
			If ExportStack.Count() = 1 Then
				
				For Each TPAndProperties IN ConversionRule.TabularSectionsProperties Do
					
					PCRForTP = TPAndProperties.Value;
					ReceiverTPName = TPAndProperties.Key;
					ReceiverTP = Undefined;
					If Not Receiver.Property(ReceiverTPName, ReceiverTP) Then
						Continue;
					EndIf;
					
					// Remove extra columns that could be added in the receiver.
					DeletedColumns = New Array;
					For Each Column IN ReceiverTP.Columns Do
						If PCRForTP.Find(Column.Name, "FormatProperty") = Undefined Then
							DeletedColumns.Add(Column);
						EndIf;
					EndDo;
					For Each Column IN DeletedColumns Do
						ReceiverTP.Columns.Delete(Column);
					EndDo;
					
					// Create a new T3 without restrictions of the columns type and copy the data to it.
					ReceiverNewTP = New ValueTable;
					For Each PCR IN PCRForTP Do
						ColumnName = PCR.FormatProperty;
						ReceiverNewTP.Columns.Add(ColumnName);
					EndDo;
					For Each TPReceiverPart IN ReceiverTP Do
						NewReceiverTPRow = ReceiverNewTP.Add();
						FillPropertyValues(NewReceiverTPRow, TPReceiverPart);
					EndDo;
					Receiver[ReceiverTPName] = ReceiverNewTP;
					
					For Each String IN ReceiverNewTP Do
						
						For Each PCR IN PCRForTP Do
							
							ExportProperty(
								ExchangeComponents,
								Source,
								String,
								PCR,
								ExportStack,
								2);
								
						EndDo;
						
					EndDo;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		// {Handler: OnSendData} End
		
		If ExportStack.Count() > 1 Then
			Receiver.Insert("CompoundPropertyType", ConversionRule.XDTOObjectKeyPropertiesType);
		EndIf;
		
	EndIf;
	
	Return Receiver;
	
EndFunction

// Exports a property of the infobase object according to the rules.
//
// Parameters:
//  ExchangeComponents   - Structure - contains all rules and parameters of exchange
//  IBData           - Reference to the exported object of the infobase.
//  PropertyReceiver - The structure which should store the value of the exported property.
//  PCR                - Table row of the properties conversion rules according to which it is converted.
//  ExportStack       - An array contains references to the exported objects taking the inclusion into account.
//  ExportStage       - Number 
//     1 - export to perform the
// OnSendData algorithm, 2 - export after the OnSendData algorithm.
//
Procedure ExportProperty(ExchangeComponents, IBData, PropertyReceiver, PCR, ExportStack, ExportStage = 1) Export
	// Property of the format is not specified - PCR data is used only on import.
	If TrimAll(PCR.FormatProperty) = "" Then
		Return;
	EndIf;
	
	PropertyValue = Undefined;
	If ExportStage = 1 Then
		If ValueIsFilled(PCR.ConfigurationProperty) Then
			PropertyValue = IBData[PCR.ConfigurationProperty];
		ElsIf Not IBData.Property(PCR.FormatProperty, PropertyValue) Then
			// It is PCR form OCR with a source-structure and there is no needed value in the source.
			Return;
		EndIf;
	Else
		
		If TypeOf(PropertyReceiver) = Type("ValueTableRow") Then
			
			If PropertyReceiver.Owner().Columns.Find(PCR.FormatProperty) = Undefined Then
				Return;
			Else
				PropertyValue = PropertyReceiver[PCR.FormatProperty];
			EndIf;
		
		ElsIf Not PropertyReceiver.Property(PCR.FormatProperty, PropertyValue)
			AND Not (ExportStack.Count() = 1 AND PropertyReceiver.KeyProperties.Property(PCR.FormatProperty, PropertyValue)) Then
			Return;
		EndIf;
		
	EndIf;
		
	PropertyConversionRule = PCR.PropertyConversionRule;
	
	// The value can be in the form of instruction.
	If TypeOf(PropertyValue) = Type("Structure") Then
		If PropertyValue.Property("OCRName") Then
			PropertyConversionRule = PropertyValue.OCRName;
		EndIf;
		If PropertyValue.Property("Value") Then
			PropertyValue = PropertyValue.Value;
		EndIf;
	EndIf;
	
	If ValueIsFilled(PropertyValue) Then
	
		If TrimAll(PropertyConversionRule) <> "" Then
			
			PDCR = ExchangeComponents.PredefinedDataConversionRules.Find(PropertyConversionRule, "PDCRName");
			If PDCR <> Undefined Then
				PropertyValue = PDCR.ValuesConversionsOnSend.Get(PropertyValue);
			Else
			
				ConversionRule = OCRByName(ExchangeComponents, PropertyConversionRule);
				
				ExportStackBranch = New Array;
				For Each Item IN ExportStack Do
					ExportStackBranch.Add(Item);
				EndDo;
				
				PropertyValue = XDTODataFromIBData(
					ExchangeComponents,
					PropertyValue,
					ConversionRule,
					ExportStackBranch);
					
			EndIf;
			
		EndIf;
		
	Else
		PropertyValue = Undefined;
	EndIf;
	
	If ExportStack.Count() = 1 AND PCR.KeyPropertiesProcessing Then
		If Not PropertyReceiver.Property("KeyProperties") Then
			PropertyReceiver.Insert("KeyProperties", New Structure);
		EndIf;
		PropertyReceiver.KeyProperties.Insert(PCR.FormatProperty, PropertyValue);
	Else
		If TypeOf(PropertyReceiver) = Type("ValueTableRow") Then
			PropertyReceiver[PCR.FormatProperty] = PropertyValue;
		Else
			PropertyReceiver.Insert(PCR.FormatProperty, PropertyValue);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region DataReceiving

// Returns the object of the infobase corresponding to the received data.
// 
// Parameters:
//  XDTOData - Structure - structure which simulates the XDTO object.
//
//  ConversionRule - ValueTableRow - parameters of the current conversion rule.
//
//  Action - String - defines the aim of getting an IB object.:
//           GetRef - object
//           identification, ConvertIntoReceivedData - filling an object only with the
//                                               data received as a result of the XDTO ConvertAndWrite data conversion. - get
//                                               object, ready.
//
// Returns:
//  Structure - includes names (keys) and values of the requested attribute.
//              If a row of the claimed attributes is empty, then an empty structure returns.
//              If a null reference is transferred as an object, then all attributes return with the Undefined value.
//
Function XDTOObjectStructureInIBData(ExchangeComponents, XDTOData, ConversionRule, Action = "ConvertAndWrite") Export
	
	IBData = Undefined;
	ReceivedData = InitializeReceivedData(ConversionRule);
	ReceivedDataRef = ReceivedData.Ref;
	IdentificationVariant = TrimAll(ConversionRule.IdentificationVariant);
	
	If IdentificationVariant = "ByUniqueIdidentificator"
		Or IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields" Then
		
		ReceivedDataRef = XDTOObjectObjectRefByUDID(
			XDTOData.Ref.Value,
			ConversionRule.DataType,
			ExchangeComponents);
			
		ReceivedData.SetNewObjectRef(ReceivedDataRef);
		
		IBData = ReceivedDataRef.GetObject();
		
		If Action = "GetRef" Then
			
			If IBData <> Undefined Then
				// Task - getting reference.
				// Identification - by UDID or UDID + search fields.
				// Object with a received reference (or with a public identifier) exists.
				Return IBData.Ref;
			ElsIf IdentificationVariant = "ByUniqueIdidentificator" Then
				// Task - getting reference.
				// Identification - according to UOID.
				// Object with a received reference (or with a public identifier) is not found.
				Return ReceivedDataRef;
			EndIf;
			
		EndIf;
	Else
		ReceivedDataRef = ConversionRule.ObjectManager.GetRef(New UUID());
		ReceivedData.SetNewObjectRef(ReceivedDataRef);
	EndIf;
	
	// Define which properties should be converted.
	PropertiesContent = ?(Action = "GetRef", "SearchProperties", "All");
	
	// Conversion of the properties which does not require the handler.
	XDTOObjectStructurePropertiesConversion(
		ExchangeComponents,
		XDTOData,
		ReceivedData,
		ConversionRule,
		1,
		PropertiesContent);
		
	If Action = "GetRef" Then
		XDTOData = New Structure("KeyProperties", XDTOData);
	EndIf;
	
	OnConvertXDTOData(
		XDTOData,
		ReceivedData,
		ExchangeComponents,
		ConversionRule.OnConvertXDTOData);
		
	If Action = "GetRef" Then
		XDTOData = XDTOData.KeyProperties;
	EndIf;
		
	XDTOObjectStructurePropertiesConversion(
		ExchangeComponents,
		XDTOData,
		ReceivedData,
		ConversionRule,
		2,
		PropertiesContent);
		
	If IBData = Undefined Then
		
		If IdentificationVariant = "BySearchFields"
			Or IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields" Then
			
			IBData = ObjectRefByXDTOObjectProperties(ConversionRule, ReceivedData);
			If Not ValueIsFilled(IBData) Then
				IBData = Undefined;
			EndIf;
			
			If IBData <> Undefined Then
				
				If Action = "GetRef" Then
					
					// Task - getting reference.
					// Identification - by UDID + search fields.
					// Object is found by search fields.
					Return IBData;
				Else
					IBData = IBData.GetObject();
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If ExchangeComponents.DataImportToInformationBaseMode
		AND (IdentificationVariant = "BySearchFields"
			Or IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields") Then
		Action = "ConvertAndWrite";
	EndIf;
	
	If Action = "ConvertAndWrite" Then
		
		#Region ObjectWrite
		
		If ExchangeComponents.IsExchangeThroughExchangePlan
			AND IBData <> Undefined
			AND IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields" Then
			
			WritePublicIdentifierIfNeeded(
				IBData,
				ReceivedData.GetNewObjectRef(),
				ExchangeComponents.CorrespondentNode,
				ConversionRule);
				
		EndIf;
		
		If ConversionRule.HasHandlerBeforeWriteReceivedData Then
			
			BeforeReceivedDataWrite(
				ReceivedData,
				IBData,
				ExchangeComponents,
				ConversionRule.BeforeReceivedDataWrite,
				ConversionRule.Properties);
			
		EndIf;
		
		If IBData = Undefined Then
			DataForEIBWrite = ReceivedData;
		Else
			If ReceivedData <> Undefined Then
				FillIBDataByReceivedData(IBData, ReceivedData, ConversionRule);
			EndIf;
			DataForEIBWrite = IBData;
		EndIf;
		
		DoNumberCodeGenerationIfNeeded(DataForEIBWrite);
		
		If ExchangeComponents.IsExchangeThroughExchangePlan Then
			
			#Region SystemHandlerOnReceiveDataFromSubordinate
				ItemReceive = DataItemReceive.Auto;
				SendBack = False;
				StandardSubsystemsServer.OnReceiveDataFromSubordinate(DataForEIBWrite, ItemReceive, SendBack, ExchangeComponents.CorrespondentNode);
			#EndRegion
			
		EndIf;
		If DataForEIBWrite.DeletionMark Then
			DataForEIBWrite.DeletionMark = False;
		EndIf;
		
		ObjectMetadata = DataForEIBWrite.Metadata();
		If Metadata.Documents.Contains(ObjectMetadata) Then
			
			Try
			
				If DataForEIBWrite.Posted Then
					
					DataForEIBWrite.Posted = False;
					If Not DataForEIBWrite.IsNew()
						AND CommonUse.ObjectAttributeValue(DataForEIBWrite.Ref, "Posted") Then
						// Write a new version of the document and cancel posting.
						Result = UndoObjectPostingInIB(DataForEIBWrite, ExchangeComponents.CorrespondentNode);
					Else
						// Write new version of the document.
						WriteObjectToIB(ExchangeComponents, DataForEIBWrite, ConversionRule.DataType);
					EndIf;
					
					TableRow = ExchangeComponents.DocumentsForDelayedPosting.Add();
					TableRow.DocumentRef = DataForEIBWrite.Ref;
					TableRow.DocumentDate  = DataForEIBWrite.Date;
					
				Else
					If DataForEIBWrite.IsNew() Then
						WriteObjectToIB(ExchangeComponents, DataForEIBWrite, ConversionRule.DataType);
					Else
						UndoObjectPostingInIB(DataForEIBWrite, ExchangeComponents.CorrespondentNode);
					EndIf;
				EndIf;
				
			Except
			EndTry;
			
		Else
			
			WriteObjectToIB(ExchangeComponents, DataForEIBWrite, ConversionRule.DataType);
			
			ExchangeComponents.ObjectsForPostponedRecording.Insert(
				DataForEIBWrite.Ref, DataForEIBWrite.AdditionalProperties);
			
		EndIf;
		
		RememberObjectForPendingFilling(DataForEIBWrite, ConversionRule, ExchangeComponents);
		
		#EndRegion
		
	Else
		
		DataForEIBWrite = ReceivedData;
		
	EndIf;
	
	Return DataForEIBWrite;
	
EndFunction

// Reads the data file on export.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//
Procedure ReadData(ExchangeComponents, TableToImport = Undefined) Export
	
	If TypeOf(TableToImport) = Type("ValueTable")
		AND TableToImport.Count() = 0 Then
		Return;
	EndIf;
	
	ObjectsArrayForDeletion = New Array;
	ImportedObjectsArray = New Array;
	
	ExchangeComponents.ExchangeManager.BeforeConversion(ExchangeComponents);
	
	While ExchangeComponents.ExchangeFile.NodeType = XMLNodeType.StartElement Do
		#Region XDTOItemReading
		SendBack = False;
		IBData = Undefined;
		
		// Get from the XDTOObject file.
		XDTODataObject = XDTOFactory.ReadXML(
			ExchangeComponents.ExchangeFile,
			XDTOFactory.Type(ExchangeComponents.ExchangeFile.NamespaceURI, ExchangeComponents.ExchangeFile.LocalName));
		
		// Import a sign of the object deletion - specific logic.
		If XDTODataObject.Type().Name = "ObjectDeletion" Then
			
			ReadDeletion(ExchangeComponents, XDTODataObject, ObjectsArrayForDeletion, TableToImport);
			
		Else
			
			// DER
			// processing Search data processing rule.
			DataProcessorRule = DERByXDTOObjectType(ExchangeComponents, XDTODataObject.Type().Name, True);
			
			If Not ValueIsFilled(DataProcessorRule) Then
				Continue;
			EndIf;

			// Convert XDTOObject into Structure.
			XDTOData = XDTOObjectToStructure(XDTODataObject);
			
			UseOCR = New Structure;
			For Each OCRName IN DataProcessorRule.UsedOCR Do
				UseOCR.Insert(OCRName, True);
			EndDo;
		#EndRegion
			
			#Region OnProcess
			If ValueIsFilled(DataProcessorRule.OnProcess) Then
				OnProcessDER(
					ExchangeComponents,
					DataProcessorRule,
					XDTOData,
					UseOCR);
			EndIf;
			#EndRegion
			
			// Array is needed for OCR wrapper by metadata objects kinds.
			MetadataObjectsProcessedTypes = New Array;
			
			// 1. Search the conversion rule.
			For Each CurrentOCR IN UseOCR Do
				
				ConversionRule = OCRByName(ExchangeComponents, CurrentOCR.Key);
				
				#Region CheckTableForImportMatch
				If TableToImport <> Undefined Then
					ObjectTypeAsString = ConversionRule.ReceivedDataTypeRow;
					
					SourceTypeAsString = XDTODataObject.Type().Name;
					ReceiverTypeAsString = ConversionRule.ReceivedDataTypeRow;
					
					DataTableKey = DataExchangeServer.DataTableKey(SourceTypeAsString, ReceiverTypeAsString, False);
					
					If TableToImport.Find(DataTableKey) = Undefined Then
						Continue;
					EndIf;
				EndIf;
				#EndRegion
				
				If CurrentOCR.Value Then
				
					ReceivedDataRef = Undefined;
					IdentificationVariant = TrimAll(ConversionRule.IdentificationVariant);
					If IdentificationVariant = "ByUniqueIdidentificator"
						Or IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields" Then
						ReceivedDataRef = ConversionRule.ObjectManager.GetRef(New UUID(XDTOData.Ref.Value));
					EndIf;
					
					If ExchangeComponents.DataImportToInformationBaseMode Then
						
						DataForEIBWrite = XDTOObjectStructureInIBData(ExchangeComponents, XDTOData, ConversionRule, "ConvertAndWrite");
						
						If ConversionRule.IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields"
							Or ConversionRule.IdentificationVariant = "ByUniqueIdidentificator" Then
							
							ImportedObjectsArray.Add(DataForEIBWrite.Ref);
							
						EndIf;
						
					ElsIf TableToImport <> Undefined Then
						
						DataForEIBWrite = XDTOObjectStructureInIBData(ExchangeComponents, XDTOData, ConversionRule, "Convert");
						
						DoNumberCodeGenerationIfNeeded(DataForEIBWrite);
						
						UUIDString = XDTOData.Ref.Value;
						
						ExchangeMessageDataTable = ExchangeComponents.DataTablesOfExchangeMessage.Get(DataTableKey);
						
						TableRow = ExchangeMessageDataTable.Find(UUIDString, "UUID");
						
						If TableRow = Undefined Then
							
							TableRow = ExchangeMessageDataTable.Add();
							
							TableRow.TypeAsString              = ReceiverTypeAsString;
							TableRow.UUID = UUIDString;
							
						EndIf;
						
						// Fill values of the object properties.
						FillPropertyValues(TableRow, DataForEIBWrite);
						TableRow.Ref = ReceivedDataRef;
						
					EndIf;
					
				ElsIf ConversionRule.IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields"
					Or ConversionRule.IdentificationVariant = "ByUniqueIdidentificator" Then
					ObjectsArrayForDeletion.Add(XDTOObjectObjectRefByUDID(XDTOData.Ref.Value, ConversionRule.DataType, ExchangeComponents));
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	If ExchangeComponents.DataImportToInformationBaseMode Then
		ApplyObjectDeletion(ExchangeComponents, ObjectsArrayForDeletion, ImportedObjectsArray);
		DelayedObjectsFilling(ExchangeComponents);
		RunDelayedDocumentPosting(ExchangeComponents);
		PerformPostponedObjectsRecording(ExchangeComponents);
	EndIf;
	
	ExchangeComponents.ExchangeManager.AfterConversion(ExchangeComponents);
	
EndProcedure

// Reads the data file on import in the analysis mode (during the interactive data synchronization).
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//
Procedure ReadDataInAnalysisMode(ExchangeComponents, AnalysisParameters = Undefined) Export
	
	// Default parameters
	StatisticsCollectParameters = New Structure("CollectClassifiersStatistics", False);
	If AnalysisParameters <> Undefined Then
		FillPropertyValues(StatisticsCollectParameters, AnalysisParameters);
	EndIf;
	
	ExchangeComponents.ExchangeManager.BeforeConversion(ExchangeComponents);
	
	// Default parameters
	StatisticsCollectParameters = New Structure("CollectClassifiersStatistics", False);
	If AnalysisParameters <> Undefined Then
		FillPropertyValues(StatisticsCollectParameters, AnalysisParameters);
	EndIf;
	
	ObjectsArrayForDeletion = New Array;
	ImportedObjectsArray = New Array;
	While ExchangeComponents.ExchangeFile.NodeType = XMLNodeType.StartElement Do
		
		// Get from the XDTOObject file.
		XDTODataObject = XDTOFactory.ReadXML(
			ExchangeComponents.ExchangeFile,
			XDTOFactory.Type(ExchangeComponents.ExchangeFile.NamespaceURI, ExchangeComponents.ExchangeFile.LocalName));
		
		If XDTODataObject.Type().Name = "ObjectDeletion" Then
			
			ReadDeletion(ExchangeComponents, XDTODataObject, ObjectsArrayForDeletion);
			
		Else
		
			DataProcessorRule = DERByXDTOObjectType(ExchangeComponents, XDTODataObject.Type().Name, True);
			
			If Not ValueIsFilled(DataProcessorRule) Then
				Return;
			EndIf;
			
			// Convert XDTOObject into Structure.
			XDTOData = XDTOObjectToStructure(XDTODataObject);
			
			UseOCR = New Structure;
			For Each OCRName IN DataProcessorRule.UsedOCR Do
				UseOCR.Insert(OCRName, True);
			EndDo;
			
			If ValueIsFilled(DataProcessorRule.OnProcess) Then
				OnProcessDER(
					ExchangeComponents,
					DataProcessorRule,
					XDTOData,
					UseOCR);
			EndIf;
			
			// 1. Search the conversion rule.
			For Each CurrentOCR IN UseOCR Do
				
				ConversionRule = ExchangeComponents.ObjectConversionRules.Find(CurrentOCR.Key, "OCRName");
				
				If CurrentOCR.Value Then
					
					TableRow = ExchangeComponents.DataTableOfPackageHeader.Add();
					
					TableRow.ObjectTypeAsString = ConversionRule.ReceivedDataTypeRow;
					TableRow.ObjectsCountInSource = 1;
					
					TableRow.ReceiverTypeAsString = ConversionRule.ReceivedDataTypeRow;
					TableRow.SourceTypeAsString = XDTODataObject.Type().Name;
					
					TableRow.SearchFields  = ConversionRule.FieldsObjectPresentation;
					TableRow.TableFields = ConversionRule.ReceivedDataHeaderAttributesRow;
					
					TableRow.SynchronizeByID  = ConversionRule.IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields"
						Or ConversionRule.IdentificationVariant = "ByUniqueIdidentificator";
						
					TableRow.UsePreview = TableRow.SynchronizeByID;
					TableRow.IsClassifier                    = ConversionRule.IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields";
					TableRow.ThisIsObjectDeletion = False;
					
					If TableRow.SynchronizeByID Then
						ImportedObjectsArray.Add(XDTOObjectObjectRefByUDID(XDTOData.Ref.Value, ConversionRule.DataType, ExchangeComponents));
					EndIf;
					
				ElsIf ConversionRule.IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields"
					Or ConversionRule.IdentificationVariant = "ByUniqueIdidentificator" Then
					ObjectsArrayForDeletion.Add(XDTOObjectObjectRefByUDID(XDTOData.Ref.Value, ConversionRule.DataType, ExchangeComponents));
				EndIf;
				
			EndDo;
		EndIf;
		
	EndDo;
	
	ApplyObjectDeletion(ExchangeComponents, ObjectsArrayForDeletion, ImportedObjectsArray);
	
EndProcedure

// Opens the file of data export, writes the title of file according to an exchange format.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//  ExchangeFileName - String
//
Procedure OpenExportFile(ExchangeComponents, ExchangeFileName = "") Export

	ExchangeFile = New XMLWriter;
	If ExchangeFileName <> "" Then
		ExchangeFile.OpenFile(ExchangeFileName);
	Else
		ExchangeFile.SetString();
	EndIf;
	ExchangeFile.WriteXMLDeclaration();
	
	WriteMessage = Undefined;
	
	If ExchangeComponents.IsExchangeThroughExchangePlan Then

		WriteMessage = New Structure("ReceivedNumber, MessageNumber, Receiver");
		WriteMessage.Recipient = ExchangeComponents.CorrespondentNode;
		
		If TransactionActive() Then
			Raise NStr("en='Exchange data lock cannot be set in an active transaction.';ru='Блокировка на обмен данными не может быть установлена в активной транзакции.'");
		EndIf;
		
		// Set the lock on the recipient node.
		Try
			LockDataForEdit(WriteMessage.Recipient);
		Except
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Setting lock on data exchange error.
		|Data exchange may be performed by another session.
		|
		|Details:
		|%1';ru='Ошибка установки блокировки на обмен данными.
		|Возможно, обмен данными выполняется другим сеансом.
		|
		|Подробности:
		|%1'"),
				BriefErrorDescription(ErrorInfo())
			);
		EndTry;
		
		ReceiverData = CommonUse.ObjectAttributesValues(WriteMessage.Recipient, "SentNumber, ReceivedNumber, Code");
		
		WriteMessage.MessageNo = ReceiverData.SentNo + 1;
		WriteMessage.ReceivedNo = ReceiverData.ReceivedNo;
		
	EndIf;
	
	// Write the <Message> item
	ExchangeFile.WriteStartElement("Message");
	ExchangeFile.WriteNamespaceMapping("msg", "http://www.1c.ru/SSL/Exchange/Message");
	ExchangeFile.WriteNamespaceMapping("xs", "http://www.w3.org/2001/XMLSchema");
	ExchangeFile.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	
	// Write the <Header> item
	Header = XDTOFactory.Create(XDTOFactory.Type(XMLBasicSchema(), "Header"));
	Header.Format = ExchangeComponents.XMLSchema;
	Header.CreationDate = CurrentUniversalDate();
	
	If ExchangeComponents.IsExchangeThroughExchangePlan Then
		
		Confirmation = XDTOFactory.Create(XDTOFactory.Type(XMLBasicSchema(), "Confirmation"));
		If ExchangeComponents.IsExchangeThroughExchangePlan Then
			Confirmation.ExchangePlan = WriteMessage.Recipient.Metadata().Name;
			Confirmation.To = TrimAll(ReceiverData.Code);
			Confirmation.From = TrimAll(DataExchangereuse.GetThisNodeCodeForExchangePlan(Confirmation.ExchangePlan));
			Confirmation.MessageNo = WriteMessage.MessageNo;
			Confirmation.ReceivedNo = WriteMessage.ReceivedNo;
		EndIf;
		Header.Confirmation = Confirmation;
		
	EndIf;
	
	If ExchangeComponents.IsExchangeThroughExchangePlan Then
		For Each FormatVersion IN ExchangeFormatVersionsArray(ExchangeComponents.CorrespondentNode) Do
			Header.AvailableVersion.Add(FormatVersion);
		EndDo;
	Else
		Header.AvailableVersion.Add(ExchangeComponents.ExchangeFormatVersion);
	EndIf;
	
	XDTOFactory.WriteXML(ExchangeFile, Header);
	
	// Write the <Body> item
	ExchangeFile.WriteStartElement("Body");
	ExchangeFile.WriteNamespaceMapping("", ExchangeComponents.XMLSchema);
	
	ExchangeComponents.Insert("ExchangeFile", ExchangeFile);
	
EndProcedure

// Opens the file of data import, writes the title of file according to an exchange format.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//  ExchangeFileName - String
//
Procedure OpenImportFile(ExchangeComponents, ExchangeFileName) Export
	
	IsExchangeThroughExchangePlan = ExchangeComponents.IsExchangeThroughExchangePlan;
	
	XMLReader = New XMLReader;
	
	IterationNumber = 0;
	ExchangeComponents.ErrorFlag = True;
	While IterationNumber = 0 Do
		
		IterationNumber = 1;
		
		Try
			XMLReader.OpenFile(ExchangeFileName);
			XMLReader.Read(); // Message
		Except
			
			ErrorMessageString = NStr("en='An error occurred when importing data: %1';ru='Ошибка при загрузке данных: %1'");
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, ErrorDescription());
			WriteInExecutionProtocol(ExchangeComponents, ErrorMessageString);
			Break;
			
		EndTry;
		
		If (XMLReader.NodeType <> XMLNodeType.StartElement
			Or XMLReader.LocalName <> "Message") Then
			WriteInExecutionProtocol(ExchangeComponents, 9);
			Break;
		EndIf;
		
		XMLReader.Read(); // Header
		If XMLReader.NodeType <> XMLNodeType.StartElement
			Or XMLReader.LocalName <> "Header" Then
			WriteInExecutionProtocol(ExchangeComponents, 9);
			Break;
		EndIf;
		
		Header = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type(XMLBasicSchema(), "Header"));
		If XMLReader.NodeType <> XMLNodeType.StartElement
			Or XMLReader.LocalName <> "Body" Then
			WriteInExecutionProtocol(ExchangeComponents, 9);
			Break;
		EndIf;
		
		
		If IsExchangeThroughExchangePlan Then
			
			If Not Header.IsSet("Confirmation") Then
				WriteInExecutionProtocol(ExchangeComponents, 9);
				Break;
			EndIf;
			
			Confirmation = Header.Confirmation;
			
			FromWhomCode = Confirmation.From;
			CodeToWhom = Confirmation.To;
			ExchangePlanName = Confirmation.ExchangePlan;
			ExchangeComponents.IncomingMessageNumber = Confirmation.MessageNo;
			ExchangeComponents.MessageNumberReceivedByCorrespondent = Confirmation.ReceivedNo;
			
			If Metadata.ExchangePlans.Find(ExchangePlanName) = Undefined Then
				WriteInExecutionProtocol(ExchangeComponents, 177);
				Break;
			EndIf;
			
			ReceiverFromMessage = ExchangePlans[ExchangePlanName].FindByCode(CodeToWhom);
			If ReceiverFromMessage <> ExchangePlans[ExchangePlanName].ThisNode() Then
				WriteInExecutionProtocol(ExchangeComponents, 178);
				Break;
			EndIf;
			
			SenderFromMessage = ExchangePlans[ExchangePlanName].FindByCode(FromWhomCode);
			If SenderFromMessage.IsEmpty()
				Or SenderFromMessage <> ExchangeComponents.CorrespondentNode Then
				
				MessageString = NStr("en='Exchange node for data import is not found. Exchange plan: %1, Code: %2';ru='Не найден узел обмена для загрузки данных. План обмена: %1, Код: %2'");
				MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ExchangePlanName, FromWhomCode);
				Raise MessageString;
				
			EndIf;
			
		EndIf;
		
		ExchangeFormat = ArrangeExchangeFormat(Header.Format);
		
		If IsExchangeThroughExchangePlan Then
			
			// Check the basic format
			ExchangePlanManager = ExchangePlanManager(ExchangeComponents.CorrespondentNode);
			If ExchangePlanManager.ExchangeFormat() <> ExchangeFormat.BasicFormat Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Exchange message format <%1> does not correspond to exchange plan format <%2>.';ru='Формат сообщения обмена <%1> не соответствует формату плана обмена <%2>.'"),
					ExchangeFormat.BasicFormat,
					ExchangePlanManager.ExchangeFormat()
				);
			EndIf;
			
			// Check format version of the exchange message.
			If ExchangeFormatVersionsArray(ExchangeComponents.CorrespondentNode).Find(ExchangeFormat.Version) = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Version of exchange message format <%1> is not supported.';ru='Версия формата сообщения обмена <%1> не поддерживается.'"),
					ExchangeFormat.Version
				);
			EndIf;
			
			If CommonUse.ObjectAttributeValue(ExchangeComponents.CorrespondentNode, "ReceivedNo") >= ExchangeComponents.IncomingMessageNumber Then
				
				// Message number is either smaller or equals to the previously accepted one.
				ExchangeComponents.DataExchangeStatus.ExchangeProcessResult =
					Enums.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived;
					
				WriteInExecutionProtocol(ExchangeComponents, 174,,,,, True);
				Break;
				
			EndIf;
			
			// Delete registration of changes.
			ExchangePlans.DeleteChangeRecords(ExchangeComponents.CorrespondentNode, ExchangeComponents.MessageNumberReceivedByCorrespondent);
			
			// Clear sign of the initial data export.
			InformationRegisters.InfobasesNodesCommonSettings.ClearInitialDataExportFlag(
				ExchangeComponents.CorrespondentNode, ExchangeComponents.MessageNumberReceivedByCorrespondent);
		
		EndIf;	
		
		
		ExchangeComponents.XMLSchema = Header.Format;
		ExchangeComponents.ExchangeFormatVersion = ExchangeFormat.Version;
		ExchangeComponents.ExchangeManager = FormatVersionExchangeManager(
			ExchangeComponents.CorrespondentNode,
			ExchangeComponents.ExchangeFormatVersion);
			
		// Check possibility to extend the version.
		AvailableSenderVersions = Header.AvailableVersion;
		AvailableRecipientVersions = ExchangeFormatVersionsArray(ExchangeComponents.CorrespondentNode);
		CorrespondentVersionNumber = CommonUse.ObjectAttributeValue(ExchangeComponents.CorrespondentNode, "ExchangeFormatVersion");
		MaxCommonVersion = CorrespondentVersionNumber;
		For Each SenderVersionAvailable IN AvailableSenderVersions Do
			If AvailableRecipientVersions.Find(SenderVersionAvailable) = Undefined Then
				Continue;
			EndIf;
			VersionsComparisonResult = CompareVersions(TrimAll(SenderVersionAvailable), TrimAll(MaxCommonVersion));
			If VersionsComparisonResult > 0 Then
				MaxCommonVersion = SenderVersionAvailable;
			EndIf;
		EndDo;
		If MaxCommonVersion <> CorrespondentVersionNumber Then
			// A more recent common version is found.
			CorrespondentNodeObject = ExchangeComponents.CorrespondentNode.GetObject();
			CorrespondentNodeObject.ExchangeFormatVersion = MaxCommonVersion;
			CorrespondentNodeObject.Write();
			WriteInExecutionProtocol(ExchangeComponents, 
										NStr("en='Exchange format version number is changed.';ru='Изменен номер версии формата обмена.'"),,False,,, True);
		EndIf;
		
		XMLReader.Read(); // Body
		
		ExchangeComponents.ErrorFlag = False;
		
	EndDo;
	
	If ExchangeComponents.ErrorFlag Then
		XMLReader.Close();
	Else
		ExchangeComponents.Insert("ExchangeFile", XMLReader);
	EndIf;
	
EndProcedure

// Converts the XDTO object into the structure with data.
//
// Parameters:
//  XDTODataObject - Value of the XDTO type which should be transformed.
//
// Returns:
//  Structure - The structure which imitates the XDTO object.
//    Keys of the structure correspond the XDTO object properties.
//    Values correspond to the XDTO object properties values.
//
Function XDTOObjectToStructure(XDTODataObject) Export
	
	Receiver = New Structure;
	
	For Each Property IN XDTODataObject.Properties() Do
		
		XDTOPropertyConversionIntoStructureItem(XDTODataObject, Property, Receiver);
		
	EndDo;
	
	If Receiver.Property("KeyProperties")
		AND Receiver.KeyProperties.Property("Ref") Then
		Receiver.Insert("Ref", Receiver.KeyProperties.Ref);
	EndIf;
	
	Return Receiver;
EndFunction

// Converts a row UDID presentation into a reference to an object of the current infobase.
// If the object with this reference already exists, the reference returns as a result.
// If there is no object with such reference, UDID search
// in the SynchronizedObjectsPublicIdentifiers register is run.
// If the search is successful, the reference returns from the register. If the search is unsuccessful, the initial reference returns.
// 
// Parameters:
//  XDTOObjectUDID       - String - Unique identifier of the XDTO object, for
// which you need to get a reference of the relevant object from the infobase.
//
//  IBObjectValueType - Type - Type of the infobase object, to
//                               which a received link should correspond.
//
//  ExchangeComponents     - Structure - Contains all necessary data initialized
//                                     on begin of exchange (OCR, PDCR, DER etc.).
//
// Returns:
//  Reference to the object of infobase.
// 
Function XDTOObjectObjectRefByUDID(XDTOObjectUDID, IBObjectValueType, ExchangeComponents) Export
	
	SetPrivilegedMode(True);
	
	// Reference search by UDID
	RefByUDID = RefByUDID(IBObjectValueType, XDTOObjectUDID);
	If Not RefByUDID.IsEmpty() AND CommonUse.RefExists(RefByUDID) Then
		Return RefByUDID; // Object by the reference unique identifier is found.
	EndIf;
	
	// Definition of references to an object through a public reference.
	PublicRef = FindRefbyPublicIdidentifier(XDTOObjectUDID, ExchangeComponents, IBObjectValueType);
	If PublicRef <> Undefined Then
		// A sent reference is not public. Return the bad reference.
		Return PublicRef;
	EndIf;
		
	Return RefByUDID;
	
EndFunction

// Sets a value of the Import parameter for a property of the DataExchange object.
//
// Parameters:
//  Object   - object, for which the property is set.
//  Value - value of the set property Import.
//
Procedure SetDataExchangeImport(Object, Value = True, Val SendBack = False, ExchangeNodeForDataImport = Undefined) Export
	
	// Not all the objects in the exchange have the DataExchange property.
	Try
		Object.DataExchange.Load = Value;
	Except
		Return;
	EndTry;
	
	If Not SendBack
		AND ExchangeNodeForDataImport <> Undefined
		AND Not ExchangeNodeForDataImport.IsEmpty() Then
	
		Try
			Object.DataExchange.Sender = ExchangeNodeForDataImport;
		Except
		EndTry;
	
	EndIf;
	
EndProcedure

// Writes an object into the infobase.
//
// Parameters:
//  Object - Written object.
//  Type - String - String object type.
// 
Procedure WriteObjectToIB(ExchangeComponents, Object, Type, WriteObject = False, Val SendBack = False, UUIDString = "") Export
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData()
		AND Not CommonUseReUse.IsSeparatedMetadataObject(Object.Metadata().FullName(), CommonUseReUse.MainDataSeparator())
		AND Not CommonUseReUse.IsSeparatedMetadataObject(Object.Metadata().FullName(), CommonUseReUse.SupportDataSplitter()) Then
		
		ErrorMessageString = NStr("en='Attempting to change shared data (%1) in split mode.';ru='Попытка изменение неразделенных данных (%1) в разделенном режиме.'");
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, Object.Metadata().FullName());
		
		ExchangeComponents.DataExchangeStatus.ExchangeProcessResult = Enums.ExchangeExecutionResult.CompletedWithWarnings;
		WriteInExecutionProtocol(ExchangeComponents, ErrorMessageString,, False);
		
		Return;
		
	EndIf;
	
	If ExchangeComponents.IsExchangeThroughExchangePlan Then
		// Set data import for an object mode.
		SetDataExchangeImport(Object,, SendBack, ExchangeComponents.CorrespondentNode);
	Else
		SetDataExchangeImport(Object,, SendBack);
	EndIf;
	
	// Check if there is a mark of the predefined item removal.
	RemoveDeletionMarkFromPredefinedItem(Object, Type, ExchangeComponents);
	
	BeginTransaction();
	Try
		
		// Write the object in a transaction.
		Object.Write();
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		
		WriteObject = False;
		
		WriteInformationAboutErrorToProtocol(26, DetailErrorDescription(ErrorInfo()), Object, ExchangeComponents, Type);
		
		Raise ExchangeComponents.ErrorMessageString;
		
	EndTry;
	
EndProcedure

// Posts delayed imported documents after all data was imported.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//
Procedure RunDelayedDocumentPosting(ExchangeComponents) Export
	
	DocumentsForDelayedPosting = ExchangeComponents.DocumentsForDelayedPosting;
	If DocumentsForDelayedPosting.Count() = 0 Then
		Return // no documents in the queue
	EndIf;
	
	// Collapse table by  unique fields.
	DocumentsForDelayedPosting.GroupBy("DocumentRef, DocumentDate, DocumentPostedSuccessfully", "IsCollision");
	
	// Sort documents by ascending order of document dates.
	DocumentsForDelayedPosting.Sort("DocumentDate");
	
	DataExchangeServer.SkipChangeProhibitionCheck();
	
	For Each TableRow IN DocumentsForDelayedPosting Do
		
		If TableRow.DocumentRef.IsEmpty() Then
			Continue;
		EndIf;
		
		Object = TableRow.DocumentRef.GetObject();
		
		If Object = Undefined Then
			Continue;
		EndIf;
		
		ExecuteDocumentRealizationOnImport(ExchangeComponents, Object, True);
		
		TableRow.DocumentPostedSuccessfully = Not Object.Posted;
		
	EndDo;
	
	DataExchangeServer.SkipChangeProhibitionCheck(False);
	
EndProcedure

// Posts a document on import to the infobase.
//
// Parameters:
//  ExchangeComponents                         - Structure - contains all rules and parameters of exchange
//  Object                                   - DocumentObject (imported document).
//  RegisterProblemsInExchangeResults - Boolean
//
Procedure ExecuteDocumentRealizationOnImport(
		ExchangeComponents,
		Object,
		RegisterProblemsInExchangeResults = False) Export
	
	ErrorDescription = "";
	DocumentPostedSuccessfully = False;
	
	EventLogMonitorMessageKey = ExchangeComponents.EventLogMonitorMessageKey;
	CorrespondentNode = ExchangeComponents.CorrespondentNode;
	
	// Set a sender node to prevent the object from being registered on the node for which importing is run, posting should not be in the import mode.
	SetDataExchangeImport(Object, False, False, CorrespondentNode);
	
	Try
		
		Object.AdditionalProperties.Insert("DeferredPosting");
		
		If Object.CheckFilling() Then
			
			// When you post the document, remove a
			// ban on the PRO execution as PRO were ignored on the regular document write to optimize the speed of the data import.
			If Object.AdditionalProperties.Property("DisableObjectChangeRecordMechanism") Then
				Object.AdditionalProperties.Delete("DisableObjectChangeRecordMechanism");
			EndIf;
			
			Object.AdditionalProperties.Insert("SkipChangeProhibitionCheck");
			
			InfoAboutObjectVersion = New Structure;
			InfoAboutObjectVersion.Insert("PostponedProcessing", True);
			InfoAboutObjectVersion.Insert("ObjectVersioningType", "ChangedByUser");
			InfoAboutObjectVersion.Insert("VersionAuthor", CorrespondentNode);
			Object.AdditionalProperties.Insert("InfoAboutObjectVersion", InfoAboutObjectVersion);
			
			// Trying to post the document
			Object.Write(DocumentWriteMode.Posting);
			
			DocumentPostedSuccessfully = Object.Posted;
			
		EndIf;
		
	Except
		
		ErrorDescription = BriefErrorDescription(ErrorInfo());
		
	EndTry;
	
	If Not DocumentPostedSuccessfully Then
		
		DataExchangeServer.RegisterErrorDocument(Object, CorrespondentNode, ErrorDescription);
		
	EndIf;
	
EndProcedure

// Cancels the object execution in the infobase.
//
// Parameters:
//  Object      - DocumentObject (document to cancel posting).
//  Sender - Reference to an exchange plan node which is a data sender.
//
Function UndoObjectPostingInIB(Object, Sender) Export
	
	// Set data import for an object mode.
	SetDataExchangeImport(Object, True, False, Sender);
	
	// Check for collisions of the import prohibition dates.
	Cancel = False;
	
	Object.AdditionalProperties.Insert("SkipChangeProhibitionCheck");
	
	BeginTransaction();
	Try
		
		// Cancel posting of the document.
		Object.Posted = False;
		Object.Write();
		
		DeleteDocumentRegisterRecords(Object, Cancel);
		
		CommitTransaction();
		
		Return True;
	Except
		RollbackTransaction();
		Return False;
	EndTry;
	
EndFunction

#EndRegion

#EndRegion

#Region ServiceProgramInterface

#Region ExchangeInitialization
// Creates values table to store the title of data package.
//
// Returns:
//  Values table
//
Function PackageHeaderDataNewTable() Export 

  DataTableOfPackageHeader = New ValueTable;
	Columns = DataTableOfPackageHeader.Columns;
	
	Columns.Add("ObjectTypeAsString",            New TypeDescription("String"));
	Columns.Add("ObjectsCountInSource", New TypeDescription("Number"));
	Columns.Add("SearchFields",                   New TypeDescription("String"));
	Columns.Add("TableFields",                  New TypeDescription("String"));
	
	Columns.Add("SourceTypeAsString", New TypeDescription("String"));
	Columns.Add("ReceiverTypeAsString", New TypeDescription("String"));
	
	Columns.Add("SynchronizeByID", New TypeDescription("Boolean"));
	Columns.Add("ThisIsObjectDeletion", New TypeDescription("Boolean"));
	Columns.Add("IsClassifier", New TypeDescription("Boolean"));
	Columns.Add("UsePreview", New TypeDescription("Boolean"));
	
	Return DataTableOfPackageHeader;
	
EndFunction

// Creates values table to store the conversion rules of object properties.
//
// Returns:
//  Values table 
//
Function InitializePropertyTableForConversionRules() Export
	
	PCRTable = New ValueTable;
	PCRTable.Columns.Add("ConfigurationProperty", New TypeDescription("String"));
	PCRTable.Columns.Add("FormatProperty", New TypeDescription("String"));
	PCRTable.Columns.Add("PropertyConversionRule", New TypeDescription("String",,,,New StringQualifiers(50)));
	PCRTable.Columns.Add("UsedConversionAlgorithm", New TypeDescription("Boolean"));
	PCRTable.Columns.Add("KeyPropertiesProcessing", New TypeDescription("Boolean"));
	PCRTable.Columns.Add("SearchPropertyProcessing", New TypeDescription("Boolean"));
	PCRTable.Columns.Add("TSName", New TypeDescription("String"));

	Return PCRTable;
	
EndFunction

// Gets rules of objects registration for an exchange plan.
//
// Returns:
//  Values table
//
Function ObjectRegistrationRules(ExchangePlanNode) Export
	ObjectRegistrationRules = DataExchangeServerCall.SessionParametersObjectRegistrationRules().Get();
	
	Filter = New Structure;
	Filter.Insert("ExchangePlanName", DataExchangereuse.GetExchangePlanName(ExchangePlanNode));
	
	ObjectRegistrationRulesTable = ObjectRegistrationRules.Copy(Filter, "MetadataObjectName, CheckBoxAttributeName");
	ObjectRegistrationRulesTable.Indexes.Add("MetadataObjectName");
	
	Return ObjectRegistrationRulesTable;
	
EndFunction

// Gets the exchange plan node properties.
//
// Returns:
//  Structure (key corresponds to the name of the property, and value - property value).
Function ExchangePlanNodeProperties(Node) Export
	
	ExchangePlanNodeProperties = New Structure;
	
	// get names of the attributes
	AttributeNames = CommonUse.NamesOfAttributesByType(Node, Type("EnumRef.ExchangeObjectsExportModes"));
	
	// Get the attributes values.
	If Not IsBlankString(AttributeNames) Then
		
		ExchangePlanNodeProperties = CommonUse.ObjectAttributesValues(Node, AttributeNames);
		
	EndIf;
	
	Return ExchangePlanNodeProperties;
EndFunction

#EndRegion

#Region DataSending
// Exports an object of the infobase.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//  Object           - Reference to the object of infobase.
//  DataProcessorRule - Values table row of the data
// processing rules corresponding to the processing rule of the exported object type.
//                     If ProcessingRight is not specified, it will be found by the metadata object of the exported object.
//
Procedure ExportSelectionObject(ExchangeComponents, Object, DataProcessorRule = Undefined) Export
	
	XMLWriter = ExchangeComponents.ExchangeFile;
	If TypeOf(Object) <> Type("Structure") Then
		
		ExchangeComponents.ExportedObjects.Add(Object.Ref);
		
		CurrentMetadataObject = Object.Metadata();
		DataProcessorRule = DERByMetadataObject(ExchangeComponents, CurrentMetadataObject);
		
	Else
		ExchangeComponents.ExportedObjects.Add(Object);
	EndIf;
	
	// Processing DER
	UseOCR = New Structure;
	For Each OCRName IN DataProcessorRule.UsedOCR Do
		UseOCR.Insert(OCRName, True);
	EndDo;
	
	If ValueIsFilled(DataProcessorRule.OnProcess) Then
		OnProcessDER(
			ExchangeComponents,
			DataProcessorRule,
			Object,
			UseOCR);
	EndIf;
	
	// Processing OCR
	SeveralOCR = (DataProcessorRule.UsedOCR.Count() > 1);
	For Each CurrentOCR IN UseOCR Do
		
		If Not CurrentOCR.Value Then
			// It there are several conversion rules and some of them are not used -
			//	you need to export the object removal if it was previously exported according to these rules.
			
			If SeveralOCR Then
				ConversionRule = ExchangeComponents.ObjectConversionRules.Find(CurrentOCR.Key, "OCRName");
				ExportDeletion(ExchangeComponents, Object.Ref, ConversionRule);
			EndIf;
			
			Continue;
		EndIf;
		
		// 1. Search the conversion rule.
		
		ConversionRule = ExchangeComponents.ObjectConversionRules.Find(CurrentOCR.Key, "OCRName");
		
		// 2. Convert Data into Structure according to the conversion rules.
		XDTOData = XDTODataFromIBData(ExchangeComponents, Object, ConversionRule, Undefined);
		
		// 3. Convert Structure into XDTOObject.
		RefsFromObject = New Array;
		XDTODataObject = XDTOObjectFromXDTOData(ExchangeComponents, XDTOData, ConversionRule.XDTOType,,RefsFromObject);
		
		Try
			XDTODataObject.Validate();
		Except
			ErrorDescriptionText = "" + ErrorDescription() + Chars.LF + TrimAll(Object);
			WriteInExecutionProtocol(ExchangeComponents, ErrorDescriptionText);
			Return;
		EndTry;
		
		If ExchangeComponents.IsExchangeThroughExchangePlan Then
			
			For Each RefValue IN RefsFromObject Do
				
				If ExchangeComponents.ExportedObjects.Find(RefValue) = Undefined
					AND ExportObjectIfNeeded(ExchangeComponents, RefValue) Then
					
					If Not InformationRegisters.ObjectDataForRegistrationInExchanges.ObjectIsInRegister(RefValue, ExchangeComponents.CorrespondentNode) Then
						
						ObjectImportedByRef = Undefined;
						
						Try
							ObjectImportedByRef = RefValue.GetObject();
						Except
						EndTry;
						
						If ObjectImportedByRef <> Undefined Then
							
							ExportSelectionObject(ExchangeComponents, ObjectImportedByRef);
							ExchangeComponents.ExportedObjectsByRef.Add(RefValue);
							InformationRegisters.ObjectDataForRegistrationInExchanges.AddObjectToFilterOfPermittedObjects(RefValue, ExchangeComponents.CorrespondentNode);
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
			
		// 4. Write XDTOObject into XML-file.
		XDTOFactory.WriteXML(XMLWriter, XDTODataObject);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ExchangeFormatVersioningProceduresAndFunctions
// Returns a data exchange manager which corresponds to the specified version of the exchange format.
//
// Parameters:
//  InfobaseNode - reference to node - correspondent.
//  FormatVersion - String
//
Function FormatVersionExchangeManager(Val InfobaseNode, Val FormatVersion) Export
	
	Result = ExchangeFormatVersions(InfobaseNode).Get(FormatVersion);
	
	If Result = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Conversion Manager for exchange format version <%1> is not defined.';ru='Не определен Менеджер конвертации для версии формата обмена <%1>.'"),
			FormatVersion
		);
	EndIf;
	
	Return Result;
EndFunction

// Returns the row with exchange format.
// Exchange format includes: 
//  Basic format for the exchange plan.
//  Version of basic format
//
// Parameters:
//  InfobaseNode - reference to node - correspondent.
//  FormatVersion - String
//
Function ExchangeFormat(Val InfobaseNode, Val FormatVersion) Export
	
	ExchangeFormat = ExchangePlanManager(InfobaseNode).ExchangeFormat();
	FormatItems = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ExchangeFormat, "/");
	FormatItems.Add(FormatVersion);
	
	Return StringFunctionsClientServer.RowFromArraySubrows(FormatItems, "/");
EndFunction

// Returns a row with a number of exchange format version supported by the data receiver.
//
// Parameters:
//  Recipient - A reference to an exchange plan, to which the data is exported.
//
Function ExchangeFormatVersionOnExport(Val Recipient) Export
	
	Result = CommonUse.ObjectAttributeValue(Recipient, "ExchangeFormatVersion");
	If Result = Undefined Then
		
		// If an exchange format version is not set, use a min version.
		Result = MinExchangeFormatVersion(Recipient);
		
	EndIf;
	
	Return TrimAll(Result);
EndFunction

// Compare two version rows.
//
// Parameters:
//  VersionString1  - String - number of version either in the 0.0.0 or 0.0 format.
//  VersionString2  - String - second compared version number.
//
// Returns:
//   Number   - more than 0 if VersionRow1 > VersionRow2; 0 if the versions are equal.
//             Less than 0 if VersionRow1 < VersionRow2
Function CompareVersions(Val VersionString1, Val VersionString2)
	
	Row1 = ?(IsBlankString(VersionString1), "0.0", VersionString1);
	Row2 = ?(IsBlankString(VersionString2), "0.0", VersionString2);
	Version1 = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Row1, ".");
	If Version1.Count() < 2 OR Version1.Count() > 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Invalid format for parameter VersionRow1: %1';ru='Неправильный формат параметра СтрокаВерсии1: %1'"), VersionString1);
	EndIf;
	Version2 = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Row2, ".");
	If Version2.Count() < 2 OR Version2.Count() > 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Invalid format for parameter VersionRow2: %1';ru='Неправильный формат параметра СтрокаВерсии2: %1'"), VersionString2);
	EndIf;
	
	Result = 0;
	If TrimAll(VersionString1) = TrimAll(VersionString2) Then
		Return 0;
	EndIf;
	
	// IN the last bit, there can be beta - this is a minimum version incompatible with any other one.
	If Version1.Count() = 3 AND TrimAll(Version1[2]) = "beta" Then
		Return -1;
	ElsIf Version2.Count() = 3 AND TrimAll(Version2[2]) = "beta" Then
		Return 1;
	EndIf;
	// Only 2 first categories are important after comparison (always a number).
	For Digit = 0 To 1 Do
		Result = Number(Version1[Digit]) - Number(Version2[Digit]);
		If Result <> 0 Then
			Return Result;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

#EndRegion

#Region Other

// Procedure adds the object of the infobase to allowed objects filter.
// Parameters:
//  Data     - reference to the IB object that should be added to the allowed objects filter.
//  Recipient - ExchangePlanRef - reference to the exchange plan, for which the object is being checked.
//
Procedure AddObjectToFilterOfPermittedObjects(Data, Recipient) Export
	
	InformationRegisters.ObjectDataForRegistrationInExchanges.AddObjectToFilterOfPermittedObjects(Data, Recipient);
	
EndProcedure

// The function returns nodes array, to which the object was previously exported.
//
// Parameters:
//  Refs            - Reference to an IB object, for which you need to get a node array.
//  ExchangePlanName    - String - name of an exchange plan as metadata object according to which the nodes are defined.
//  FlagAttributeName - String - name of the exchange plan attribute according to which a filter of nodes selection is set.
// Returns:
//  NodesArray - Nodes array of the exchange plan for which the Export if
//                needed trait was set is initially empty.
//
Function NodesArrayForRegistrationExportIfNeeded(Refs, ExchangePlanName, FlagAttributeName) Export
	
	QueryText = "
	|SELECT DISTINCT
	|	ExchangePlanHeader.Ref AS Node
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS ExchangePlanHeader
	|LEFT JOIN
	|	InformationRegister.ObjectDataForRegistrationInExchanges AS ObjectDataForRegistrationInExchanges
	|ON
	|	ExchangePlanHeader.Ref = ObjectDataForRegistrationInExchanges.InfobaseNode
	|	AND ObjectDataForRegistrationInExchanges.Ref = &Object
	|WHERE
	|	     ExchangePlanHeader.Ref <> &ThisNode
	|	AND    ExchangePlanHeader.[FlagAttributeName] = VALUE(Enum.ExchangeObjectsExportModes.ExportIfNecessary)
	|	AND Not ExchangePlanHeader.DeletionMark
	|	AND    ObjectDataForRegistrationInExchanges.Ref = &Object
	|";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]",    ExchangePlanName);
	QueryText = StrReplace(QueryText, "[FlagAttributeName]", FlagAttributeName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ThisNode", DataExchangereuse.GetThisNodeOfExchangePlan(ExchangePlanName));
	Query.SetParameter("Object",   Refs);
	
	NodesArray = Query.Execute().Unload().UnloadColumn("Node");
	
	Return NodesArray;
	
EndFunction

// Writes message in the event log.
//
// Parameters:
//  Comment      - String, comment for a record in the event log.
//  Level          - Level of the event log message (Error by default).
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//
Procedure WriteLogEventDataExchange(Comment, ExchangeComponents, Level = Undefined) Export
	
	CorrespondentNode = ExchangeComponents.CorrespondentNode;
	EventLogMonitorMessageKey = ExchangeComponents.EventLogMonitorMessageKey;
	
	If Level = Undefined Then
		Level = EventLogLevel.Error;
	EndIf;
	
	MetadataObject = Undefined;
	
	If     CorrespondentNode <> Undefined
		AND Not CorrespondentNode.IsEmpty() Then
		
		MetadataObject = CorrespondentNode.Metadata();
		
	EndIf;
	
	WriteLogEvent(EventLogMonitorMessageKey, Level, MetadataObject,, Comment);
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

#Region ExchangeInitialization
Function DataProcessingRulesTable(XMLSchema, ExchangeManager , ExchangeDirection)
	
	// Initialize rule tables of the data processing
	DataProcessingRules = New ValueTable;
	DataProcessingRules.Columns.Add("Name");
	DataProcessingRules.Columns.Add("SelectionObjectFormat");
	DataProcessingRules.Columns.Add("XDTORefType");
	DataProcessingRules.Columns.Add("SelectionObjectMetadata");
	DataProcessingRules.Columns.Add("DataSelection");
	DataProcessingRules.Columns.Add("SelectionTableName");
	DataProcessingRules.Columns.Add("OnProcess",    New TypeDescription("String"));
	
	// UsedOCR - array containing OCR names which can receive an object from this POD.
	DataProcessingRules.Columns.Add("UsedOCR",    New TypeDescription("Array"));
	
	ExchangeManager.FillDataProcessingRules(ExchangeDirection, DataProcessingRules);
	
	LineCount = DataProcessingRules.Count();
	For IterationNumber = 1 To LineCount Do
		
		RowIndex = LineCount - IterationNumber;
		DCR = DataProcessingRules.Get(RowIndex);
		
		If ExchangeDirection = "Get" Then
			
			XDTOType = XDTOFactory.Type(XMLSchema, DCR.SelectionObjectFormat);
			
			If XDTOType = Undefined Then
				DataProcessingRules.Delete(DCR);
				Continue;
			EndIf;
			
			KeyProperties = XDTOType.Properties.Get("KeyProperties");
			If KeyProperties <> Undefined Then
				
				XDTOObjectKeyPropertiesType = KeyProperties.Type;
				PropertyXDTORef = XDTOObjectKeyPropertiesType.Properties.Get("Ref");
				If PropertyXDTORef <> Undefined Then
					DCR.XDTORefType = PropertyXDTORef.Type;
				EndIf;
				
			EndIf;
			
		ElsIf DCR.SelectionObjectMetadata <> Undefined Then
			DCR.SelectionTableName = DCR.SelectionObjectMetadata.FullName();
		EndIf;
		
		
	EndDo;
	
	Return DataProcessingRules;
EndFunction

Function ConversionRulesTable(XMLSchema, ExchangeManager , ExchangeDirection)
	
	// Initialize table of the conversion rules
	ConversionRules = New ValueTable;
	ConversionRules.Columns.Add("OCRName", New TypeDescription("String",,,,New StringQualifiers(50)));
	ConversionRules.Columns.Add("ObjectData");
	ConversionRules.Columns.Add("FormatObject",                New TypeDescription("String"));
	ConversionRules.Columns.Add("ReceivedDataTypeRow",   New TypeDescription("String",,,,New StringQualifiers(300)));
	ConversionRules.Columns.Add("ReceivedDataTableName",   New TypeDescription("String",,,,New StringQualifiers(300)));
	ConversionRules.Columns.Add("ReceivedDataTypePresentation", New TypeDescription("String",,,,New StringQualifiers(300)));
	ConversionRules.Columns.Add("Properties",                     New TypeDescription("ValueTable"));
	ConversionRules.Columns.Add("SearchFields",                   New TypeDescription("Array"));
	ConversionRules.Columns.Add("TabularSectionsProperties",      New TypeDescription("Structure"));
	ConversionRules.Columns.Add("FieldsObjectPresentation",     New TypeDescription("String",,,,New StringQualifiers(300)));
	ConversionRules.Columns.Add("ReceivedDataHeaderAttributesRow", New TypeDescription("String",,,,New StringQualifiers(1000)));
	ConversionRules.Columns.Add("OnDataSending",            New TypeDescription("String"));
	ConversionRules.Columns.Add("OnConvertXDTOData",     New TypeDescription("String"));
	ConversionRules.Columns.Add("BeforeReceivedDataWrite", New TypeDescription("String"));
	ConversionRules.Columns.Add("AfterAllDataImport",      New TypeDescription("String"));
	ConversionRules.Columns.Add("ExtendedRef",            New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("RuleForCatalogGroup",  New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("IdentificationVariant",         New TypeDescription("String",,,,New StringQualifiers(60)));
	
	ExchangeManager.FillObjectConversionRules(ExchangeDirection, ConversionRules);
	
	// Add service fields of the conversion rules table
	ConversionRules.Columns.Add("XDTOType");
	ConversionRules.Columns.Add("XDTORefType");
	ConversionRules.Columns.Add("XDTOObjectKeyPropertiesType");
	ConversionRules.Columns.Add("DataType");
	
	ConversionRules.Columns.Add("ObjectManager");
	ConversionRules.Columns.Add("DescriptionFull");
	
	ConversionRules.Columns.Add("ThisIsDocument");
	ConversionRules.Columns.Add("ThisIsCatalog");
	ConversionRules.Columns.Add("IsEnum");
	ConversionRules.Columns.Add("ThisIsChartOfCharacteristicTypes");
	ConversionRules.Columns.Add("ThisIsBusinessProcess");
	ConversionRules.Columns.Add("ThisIsTask");
	ConversionRules.Columns.Add("ThisIsChartOfAccounts");
	ConversionRules.Columns.Add("ThisIsChartOfCalculationTypes");
	ConversionRules.Columns.Add("ThisIsConstant");
	
	ConversionRules.Columns.Add("IsReferenceType");
	
	ConversionRules.Columns.Add("HasHandlerOnDataSend", New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("HasHandlerOnConvertXDTOData", New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("HasHandlerBeforeWriteReceivedData", New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("HasHandlerAfterAllDataImport", New TypeDescription("Boolean"));
	
	LineCount = ConversionRules.Count();
	For IterationNumber = 1 To LineCount Do
		
		RowIndex = LineCount - IterationNumber;
		ConversionRule = ConversionRules.Get(RowIndex);
		
		If ValueIsFilled(ConversionRule.FormatObject) Then
			ConversionRule.XDTOType = XDTOFactory.Type(XMLSchema, ConversionRule.FormatObject);
			If ConversionRule.XDTOType = Undefined Then
				ConversionRules.Delete(ConversionRule);
				Continue;
			EndIf;
		EndIf;
		
		If ExchangeDirection = "Get" Then
			
			ObjectMetadata = ConversionRule.ObjectData;
		
			ConversionRule.ReceivedDataTableName = ObjectMetadata.FullName();
			ConversionRule.ReceivedDataTypePresentation = ObjectMetadata.Presentation();
			ConversionRule.ReceivedDataTypeRow = DataTypeNameByMetadataObject(ConversionRule.ObjectData, False, False);
		
			ConversionRule.FieldsObjectPresentation = ?(ConversionRule.SearchFields.Count() = 0, "", ConversionRule.SearchFields[0]);
			
			// Object attributes of the received data
			AttributeString = "";
			For Each Attribute IN ObjectMetadata.Attributes Do
				AttributesInRowCopy = AttributeString;
				AttributeString = AttributeString + ?(IsBlankString(AttributeString), "", ",") + Attribute.Name;
				If StrLen(AttributeString) > 1000 Then
					AttributeString = AttributesInRowCopy;
					Break;
				EndIf;
			EndDo;
			
			For Each Attribute IN ObjectMetadata.StandardAttributes Do
				If Attribute.Name = "Description"
					OR Attribute.Name = "Code"
					OR Attribute.Name = "Parent"
					OR Attribute.Name = "Owner"
					OR Attribute.Name = "Date"
					OR Attribute.Name = "Number" Then
					AttributesInRowCopy = AttributeString;
					AttributeString = AttributeString + ?(IsBlankString(AttributeString), "", ",") + Attribute.Name;
					If StrLen(AttributeString) > 1000 Then
						AttributeString = AttributesInRowCopy;
						Break;
					EndIf;
				EndIf;
			EndDo;
			ConversionRule.ReceivedDataHeaderAttributesRow = AttributeString;
			
			ConversionRule.HasHandlerOnConvertXDTOData     = Not IsBlankString(ConversionRule.OnConvertXDTOData);
			ConversionRule.HasHandlerBeforeWriteReceivedData = Not IsBlankString(ConversionRule.BeforeReceivedDataWrite);
			ConversionRule.HasHandlerAfterAllDataImport      = Not IsBlankString(ConversionRule.AfterAllDataImport);
			
		Else
			ConversionRule.HasHandlerOnDataSend            = Not IsBlankString(ConversionRule.OnDataSending);
		EndIf;
		
		If ConversionRule.ObjectData <> Undefined Then
			
			ConversionRule.DescriptionFull                  = ConversionRule.ObjectData.FullName();
			ConversionRule.ObjectManager            = CommonUse.ObjectManagerByFullName(ConversionRule.DescriptionFull);
			
			BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(ConversionRule.ObjectData);
			
			ConversionRule.DataType = Type(DataTypeNameByMetadataObject(ConversionRule.ObjectData, False, False));
			
		Else
			BaseTypeName = "";
		EndIf;
		
		ConversionRule.ThisIsDocument               = (BaseTypeName = CommonUse.TypeNameDocuments());
		ConversionRule.ThisIsCatalog             = (BaseTypeName = CommonUse.TypeNameCatalogs());
		ConversionRule.IsEnum           = (BaseTypeName = CommonUse.TypeNameEnums());
		ConversionRule.ThisIsChartOfCharacteristicTypes = (BaseTypeName = CommonUse.TypeNameChartsOfCharacteristicTypes());
		ConversionRule.ThisIsBusinessProcess          = (BaseTypeName = CommonUse.BusinessProcessTypeName());
		ConversionRule.ThisIsTask                 = (BaseTypeName = CommonUse.TypeNameTasks());
		ConversionRule.ThisIsChartOfAccounts             = (BaseTypeName = CommonUse.TypeNameChartsOfAccounts());
		ConversionRule.ThisIsChartOfCalculationTypes       = (BaseTypeName = CommonUse.TypeNameChartsOfCalculationTypes());
		ConversionRule.ThisIsConstant              = (BaseTypeName = CommonUse.TypeNameConstants());
		
		ConversionRule.IsReferenceType = ConversionRule.ThisIsDocument
			Or ConversionRule.ThisIsCatalog
			Or ConversionRule.ThisIsChartOfCharacteristicTypes
			Or ConversionRule.ThisIsBusinessProcess
			Or ConversionRule.ThisIsTask
			Or ConversionRule.ThisIsChartOfAccounts
			Or ConversionRule.ThisIsChartOfCalculationTypes;
		
		If ValueIsFilled(ConversionRule.FormatObject) Then
			KeyProperties = ConversionRule.XDTOType.Properties.Get("KeyProperties");
			If KeyProperties <> Undefined Then
				
				XDTOObjectKeyPropertiesType = KeyProperties.Type;
				ConversionRule.XDTOObjectKeyPropertiesType = XDTOObjectKeyPropertiesType;
				
				PCRTable = ConversionRule.Properties;
				For Each PCR IN PCRTable Do
					
					If XDTOObjectKeyPropertiesType.Properties.Get(PCR.FormatProperty) <> Undefined Then
						PCR.KeyPropertiesProcessing = True;
					EndIf;
					
				EndDo;
				
				PropertyXDTORef = XDTOObjectKeyPropertiesType.Properties.Get("Ref");
				If PropertyXDTORef <> Undefined Then
					
					ConversionRule.XDTORefType = PropertyXDTORef.Type;
					
					If ConversionRule.IsReferenceType
						AND ExchangeDirection = "sending" Then
						PCRForRef = PCRTable.Add();
						PCRForRef.ConfigurationProperty = "Ref";
						PCRForRef.FormatProperty = "Ref";
						PCRForRef.KeyPropertiesProcessing = "True";
					EndIf;
					
				EndIf;
				
			EndIf;
		EndIf;
		
		If ConversionRule.IdentificationVariant = "BySearchFields"
			Or ConversionRule.IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields" Then
			
			PCRTable = ConversionRule.Properties;
			For Each PCR IN PCRTable Do
				
				If ValueIsFilled(ConversionRule.SearchFields) Then
					For Each SearchFieldsItem IN ConversionRule.SearchFields Do
						ArraySearchFields = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SearchFieldsItem, ",",, True);
						For Each AfterSearch IN ArraySearchFields Do
							If AfterSearch = PCR.ConfigurationProperty Then
								PCR.SearchPropertyProcessing = True;
								Break;
							EndIf;
						EndDo;
					EndDo;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		For Each CWT IN ConversionRule.TabularSectionsProperties Do
			For Each PCR IN CWT.Value Do
				
				PCR.TSName = CWT.Key;
				
			EndDo;
		EndDo;
		
	EndDo;
	
	// Add indexes of the conversion rules table
	If ExchangeDirection = "sending" Then
		
		ConversionRules.Indexes.Add("DataType");
		ConversionRules.Indexes.Add("XDTOType");
		ConversionRules.Indexes.Add("ExtendedRef");
		
	Else
		
		ConversionRules.Indexes.Add("XDTOType");
		ConversionRules.Indexes.Add("XDTORefType");
		ConversionRules.Indexes.Add("DataType");
		
	EndIf;
	
	Return ConversionRules;
EndFunction

Function PredefinedDataConversionRulesTable(XMLSchema, ExchangeManager , ExchangeDirection)
	
	// Initialize table of the conversion rules.
	ConversionRules = New ValueTable;
	ConversionRules.Columns.Add("DataType");
	ConversionRules.Columns.Add("XDTOType");
	ConversionRules.Columns.Add("ValueConversionsOnReceive");
	ConversionRules.Columns.Add("ValuesConversionsOnSend");
	
	ConversionRules.Columns.Add("PDCRName", New TypeDescription("String"));
	
	ExchangeManager.FillPredefinedDataConversionRules(ExchangeDirection, ConversionRules);
	
	For Each ConversionRule IN ConversionRules Do
	
		ConversionRule.XDTOType = XDTOFactory.Type(XMLSchema, ConversionRule.XDTOType);
		ConversionRule.DataType = Type(DataTypeNameByMetadataObject(ConversionRule.DataType, False, False));
		
	EndDo;
	
	// Add table indexes of conversion rules.
	If ExchangeDirection = "sending" Then
		
		ConversionRules.Indexes.Add("DataType");
		ConversionRules.Indexes.Add("XDTOType");
		
	Else
		
		ConversionRules.Indexes.Add("XDTOType");
		ConversionRules.Indexes.Add("DataType");
		
	EndIf;
	
	Return ConversionRules;
	
EndFunction

Function ConversionParametersStructure(ExchangeManager)
	// Initialization of the structure with conversion parameters.
	//	Later you may need not the structure, but the table (if you need to
	//	transfer parameters from one base to another).
	ConversionParameters = New Structure();
	ExchangeManager.FillConversionParameters(ConversionParameters);
	Return ConversionParameters;
EndFunction

#EndRegion

#Region DataSending

Procedure RunDumpOfRegisteredData(ExchangeComponents, MessageNo)
	
	NodeForExchange = ExchangeComponents.CorrespondentNode;
	
	InitialDataExport = DataExchangeServer.InitialDataExportFlagIsSet(NodeForExchange);
	
	// Get the changed data selection.
	ChangeSelection = ExchangePlans.SelectChanges(NodeForExchange, MessageNo);
	
	NodeForExchangeObject = NodeForExchange.GetObject();
	
	//  Algorithm of data export into the XML-file:
	// 1. Get Data
	// from IB 2. Send information about deleting or export data.
	// 3. Convert Data into the Structure according to a conversion rule.
	// 4. Convert data into the Structure in the OnSendData handler.
	// 5. Convert Structure into XDTOObject.
	// 6. Write XDTOObject into XML-file.
	
	While ChangeSelection.Next() Do
		
		// 1. Get Data from IB
		Data = ChangeSelection.Get();

		// 2. Send information about deleting or export data.
		If TypeOf(Data) = Type("ObjectDeletion") Then
			ExportDeletion(ExchangeComponents, Data.Ref);
		Else
			
			ItemSend = DataItemSend.Auto;
			DataExchangeEvents.OnDataSendingToCorrespondent(Data, ItemSend, InitialDataExport, NodeForExchangeObject);
			
			If ItemSend = DataItemSend.Delete Then
				ExportDeletion(ExchangeComponents, Data.Ref);
			ElsIf ItemSend = DataItemSend.Ignore Then
				// The situation when an object does not correspond to the filter criteria but does not need to be sent as removal.
				// Occurs in the case of the initial data export.
				Continue;
			Else
				ExportSelectionObject(ExchangeComponents, Data);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function IsXDTORef(Val Type)
	
	Return XDTOFactory.Type(XMLBasicSchema(), "Ref").IsDescendant(Type);
	
EndFunction

Function ExportObjectIfNeeded(ExchangeComponents, Object)
	
	MetadataObject = Metadata.FindByType(TypeOf(Object));
	
	If MetadataObject = Undefined Then
		Return False;
	EndIf;
	
	// Get setting from cache
	RegistrationIfNeeded = ExchangeComponents.MatchRegistrationIfNeeded.Get(MetadataObject);
	If RegistrationIfNeeded <> Undefined Then
		Return RegistrationIfNeeded;
	EndIf;
	
	RegistrationIfNeeded = False;
	
	Filter = New Structure("MetadataObjectName", MetadataObject.FullName());
	RuleArray = ExchangeComponents.ObjectRegistrationRulesTable.FindRows(Filter);
	
	For Each Rule IN RuleArray Do
		
		If Not IsBlankString(Rule.FlagAttributeName) Then
			
			FlagAttributeValue = Undefined;
			ExchangeComponents.ExchangePlanNodeProperties.Property(Rule.FlagAttributeName, FlagAttributeValue);
			
			RegistrationIfNeeded = (FlagAttributeValue = Enums.ExchangeObjectsExportModes.ExportIfNecessary
				Or FlagAttributeValue = Enums.ExchangeObjectsExportModes.EmptyRef());

			If RegistrationIfNeeded Then
				Break;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Save the final value to cache.
	ExchangeComponents.MatchRegistrationIfNeeded.Insert(MetadataObject, RegistrationIfNeeded);
	Return RegistrationIfNeeded;
	
EndFunction

Procedure WriteObjectDeletionXDTO(ExchangeComponents, Refs, XDTORefType)
	
	XDTOObjectUDID = InformationRegisters.SynchronizedObjectPublicIDs.PublicIdentifierByObjectRef(
		ExchangeComponents.CorrespondentNode, Refs);
		
	If Not ValueIsFilled(XDTOObjectUDID) Then
		Return;
	EndIf;
	
	XMLSchema = ExchangeComponents.XMLSchema;
	XDTOType = XDTOFactory.Type(XMLSchema, "ObjectDeletion");
	
	For Each Property IN XDTOType.Properties[0].Type.Properties[0].Type.Properties Do
		If Property.Type = XDTORefType Then
			
			XDTOValueAnyRef = XDTOFactory.Create(Property.Type, XDTOObjectUDID);
			AnyRefObject = XDTOFactory.Create(XDTOType.Properties[0].Type);
			AnyRefObject.ObjectReference = XDTOFactory.Create(XDTOType.Properties[0].Type.Properties[0].Type);
			AnyRefObject.ObjectReference.Set(Property, XDTOValueAnyRef);
			
			XDTOData = XDTOFactory.Create(XDTOType);
			XDTOData.ObjectReference = XDTOFactory.Create(XDTOType.Properties[0].Type);
			XDTOData.Set(XDTOType.Properties[0], AnyRefObject);
			XDTOFactory.WriteXML(ExchangeComponents.ExchangeFile, XDTOData);
			Break;
			
		EndIf;
	EndDo;
	
EndProcedure

// Parameters: 
//	Refs - deleted
//	ObjectComponents object - structure, contains all key data for exchange (OCR,PDCR, DCR etc.).
Procedure ExportDeletion(ExchangeComponents, Refs, ConversionRule = Undefined)
	
	If ConversionRule <> Undefined Then
		// OCR was explicit (on call to delete for a specific OCR)
		WriteObjectDeletionXDTO(ExchangeComponents, Refs, ConversionRule.XDTORefType);
	Else
		
		// Search OCR
		OCRNameArray = DERByMetadataObject(ExchangeComponents, Refs.Metadata()).UsedOCR;
		
		// Array is needed for OCR rollup by XDTO types.
		ProcessedXDTORefsTypes = New Array;
		
		For Each ConversionRuleName IN OCRNameArray Do
			
			ConversionRule = ExchangeComponents.ObjectConversionRules.Find(ConversionRuleName, "OCRName");
			
			If ConversionRule = Undefined Then
				// You can specify OCR not intended for current version of data format.
				Continue;
			EndIf;
			
			// OCR rollup by XDTO reference type.
			XDTORefType = ConversionRule.XDTORefType;
			If ProcessedXDTORefsTypes.Find(XDTORefType) = Undefined Then
				ProcessedXDTORefsTypes.Add(XDTORefType);
			Else
				Continue;
			EndIf;
			
			WriteObjectDeletionXDTO(ExchangeComponents, Refs, XDTORefType);
			
		EndDo;
		
	EndIf;
EndProcedure

Function ConvertEnumerationIntoXDTO(ExchangeComponents, EnumValue, XDTOEnumerationType)
	If TypeOf(EnumValue) = Type("String") Then
	
		XDTODataValue = XDTOFactory.Create(XDTOEnumerationType, EnumValue);
		
	Else
	
		PredefinedDataConversionRules = ExchangeComponents.PredefinedDataConversionRules;
		
		ConversionRule = FindConversionRuleForValue(
			PredefinedDataConversionRules, TypeOf(EnumValue), XDTOEnumerationType);
		
		XDTODataValue = XDTOFactory.Create(XDTOEnumerationType,
			XDTOEnumerationValue(ConversionRule.ValuesConversionsOnSend, EnumValue)
		);
		
	EndIf;
	Return XDTODataValue;
EndFunction

Function FindConversionRuleForValue(PredefinedDataConversionRules, Val Type, Val XDTOType = Undefined)
	
	If XDTOType = Undefined Then
		
		FoundRules = PredefinedDataConversionRules.FindRows(New Structure("DataType", Type));
		
		If FoundRules.Count() = 1 Then
			
			ConversionRule = FoundRules[0];
			
			Return ConversionRule;
			
		ElsIf FoundRules.Count() > 1 Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Conversion rules error of the predefined data.
		|More than one conversion rule for the <%1> source type is specified.';ru='Ошибка правил конвертации предопределенных данных.
		|Задано более одного правила конвертации для типа источника <%1>.'"),
				String(Type)
			);
			
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Conversion rules error of the predefined data.
		|Rule conversion is undefined for the <% 1> source type.';ru='Ошибка правил конвертации предопределенных данных.
		|Правило конвертации не определено для типа источника <%1>.'"),
			String(Type)
		);
			
	Else
		
		FoundRules = PredefinedDataConversionRules.FindRows(New Structure("DataType, XDTOType", Type, XDTOType, False));
		
		If FoundRules.Count() = 1 Then
			
			ConversionRule = FoundRules[0];
			
			Return ConversionRule;
			
		ElsIf FoundRules.Count() > 1 Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Conversion rules error of the predefined data.
		|More than one rule of conversion for the <%1> source type and the <%2> receiver type is specified.';ru='Ошибка правил конвертации предопределенных данных.
		|Задано более одного правила конвертации для типа источника <%1> и типа приемника <%2>.'"),
				String(Type),
				String(XDTOType)
			);
			
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Conversion rules error of the predefined data.
		|Conversion rule is not defined for a %1 source type and %2 receiver type.';ru='Ошибка правил конвертации предопределенных данных.
		|Правило конвертации не определено для типа источника <%1> и типа приемника <%2>.'"),
			String(Type),
			String(XDTOType)
		);
		
	EndIf;
	
EndFunction

Function XDTOEnumerationValue(Val ValueConversions, Val Value)
	
	XDTODataValue = ValueConversions.Get(Value);
	
	If XDTODataValue = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Conversion rule for the value of predifined data is not found.
		|Source value type:
		|<%1> Source value: <%2>';ru='Не найдено правило конвертации для значения предопределенных данных.
		|Тип значения
		|источника: <%1> Значение источника: <%2>'"),
			TypeOf(Value),
			String(Value)
		);
	EndIf;
	
	Return XDTODataValue;
EndFunction

Function ConvertRefToXDTO(ExchangeComponents, RefValue, XDTORefType)
	
	If ExchangeComponents.IsExchangeThroughExchangePlan Then
	
		XDTOObjectUDID = InformationRegisters.SynchronizedObjectPublicIDs.PublicIdentifierByObjectRef(
			ExchangeComponents.CorrespondentNode, RefValue);
		XDTODataValue = XDTOFactory.Create(XDTORefType, XDTOObjectUDID);
			
		Return XDTODataValue;
		
	Else
		Return TrimAll(RefValue.UUID());
	EndIf;
	
EndFunction

Function IsObjectTable(Val XDTOProperty)
	
	If TypeOf(XDTOProperty.Type) = Type("XDTOObjectType")
		AND XDTOProperty.Type.Properties.Count() = 1 Then
		
		Return XDTOProperty.Type.Properties[0].UpperBound <> 1;
		
	EndIf;
	
	Return False;
EndFunction

#EndRegion

#Region DataReceiving

#Region ObjectsConversion

#Region ConvertXDTOIntoStructure

Procedure XDTOPropertyConversionIntoStructureItem(Source, Property, Receiver, NameForCompoundTypeProperty = "")
	
	If Not Source.IsSet(Property) Then
		Return;
	EndIf;
	
	PropertyName = ?(NameForCompoundTypeProperty = "", Property.Name, NameForCompoundTypeProperty);
	
	XDTODataValue = Source.GetXDTO(Property);
	
	If TypeOf(XDTODataValue) = Type("XDTODataValue") Then
		
		Value = ReadXDTOValue(XDTODataValue);
		
		If TypeOf(Receiver) = Type("Structure") Then
			Receiver.Insert(PropertyName, Value);
		Else
			Receiver[PropertyName] = Value;
		EndIf;
		
	ElsIf TypeOf(XDTODataValue) = Type("XDTODataObject") Then
		
		// IN the property, there may be:
		// - additional information
		// - tabular section
		// - set of key values
		// - set of general properties
		// - compound type property.
		
		If PropertyName = "AdditionalInfo" Then // Additional information
			
			Value = XDTOSerializer.ReadXDTO(XDTODataValue);
			Receiver.Insert(PropertyName, Value);
			
		ElsIf IsObjectTable(Property) Then
			
			// Initialize values table that displays tabular section of an object.
			Value = ObjectTableByType(Property.Type.Properties[0].Type);
			
			XDTOTabularSection = Source[PropertyName].String;
			
			For IndexOf = 0 To XDTOTabularSection.Count() - 1 Do
				
				TSRow = Value.Add();
				XDTORow = XDTOTabularSection.GetXDTO(IndexOf);
				For Each TPRowProperty IN XDTORow.Properties() Do
				
					XDTOPropertyConversionIntoStructureItem(XDTORow, TPRowProperty, TSRow);
					
				EndDo;
				
			EndDo;
			
			Receiver.Insert(PropertyName, Value);
			
		ElsIf Find(XDTODataValue.Type().Name, "KeyProperties") > 0 Then
			
			Value = New Structure("IsKeyPropertiesSet");
			Value.Insert("ValueType", StrReplace(XDTODataValue.Type().Name, "KeyProperties", ""));
			For Each KeyProperty IN XDTODataValue.Properties() Do
				XDTOPropertyConversionIntoStructureItem(XDTODataValue, KeyProperty, Value);
			EndDo;
			
			
			If TypeOf(Receiver) = Type("Structure") Then
				Receiver.Insert(PropertyName, Value);
			Else
				Receiver[PropertyName] = Value;
			EndIf;
			
		ElsIf Find(XDTODataValue.Type().Name, "CommonProperties") > 0 Then
			
			For Each UnderProperty IN XDTODataValue.Properties() Do
				
				XDTOPropertyConversionIntoStructureItem(XDTODataValue, UnderProperty, Receiver);
				
			EndDo;
			
		Else
			
			// Compound type property 
			Value = Undefined;
			For Each UnderProperty IN XDTODataValue.Properties() Do
				
				If Not XDTODataValue.IsSet(UnderProperty) Then
					Continue;
				EndIf;
				
				XDTOPropertyConversionIntoStructureItem(XDTODataValue, UnderProperty, Receiver, PropertyName);
				Break;
				
			EndDo;
			
		EndIf;
		
	EndIf;

EndProcedure

Function ReadXDTOValue(XDTODataValue)
	
	If XDTODataValue = Undefined Then
		Return Undefined;
	EndIf;
	
	If IsXDTORef(XDTODataValue.Type()) Then // Reference conversion
		Value = ReadCompoundTypeXDTOValue(XDTODataValue, "Ref");
	ElsIf XDTODataValue.Type().Facets <> Undefined
		AND XDTODataValue.Type().Facets.Enums <> Undefined
		AND XDTODataValue.Type().Facets.Enums.Count() > 0 Then // Enumeration conversion
		
		Value = ReadCompoundTypeXDTOValue(XDTODataValue, "Enum");
	Else // Conversion of a regular value.
		
		Value = XDTODataValue.Value;
		
	EndIf;
	
	Return Value;
	
EndFunction

Function ReadCompoundTypeXDTOValue(XDTODataValue, ComplexType)
	
	XDTOStructure = New Structure;
	XDTOStructure.Insert("IsReference", ComplexType = "Ref");
	XDTOStructure.Insert("IsEnum", ComplexType = "Enum");
	XDTOStructure.Insert("XDTOValueType", XDTODataValue.Type());
	XDTOStructure.Insert("Value", XDTODataValue.Value);

	Return XDTOStructure;
	
EndFunction

Function ObjectTableByType(Val Type)
	
	Result = New ValueTable;
	
	For Each Column IN Type.Properties Do
		
		If Find(Column.Type.Name, "CommonProperties") > 0 Then
			
			For Each UnderColumn IN Column.Type.Properties Do
				
				Result.Columns.Add(UnderColumn.Name);
				
			EndDo;
			
		Else
			Result.Columns.Add(Column.Name);
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#Region ConversionStructureInIBData

Procedure XDTOObjectStructurePropertiesConversion(
		ExchangeComponents,
		XDTOData,
		ReceivedData,
		ConversionRule,
		StageNumber = 1,
		PropertiesContent = "All")
	
	For Each PCR IN ConversionRule.Properties Do
		
		If PropertiesContent = "SearchProperties"
			AND Not PCR.SearchPropertyProcessing Then
			Continue;
		EndIf;
		
		XDTOObjectStructurePropertyConversion(
			ExchangeComponents,
			XDTOData,
			ReceivedData.AdditionalProperties,
			ReceivedData,
			PCR,
			StageNumber);
		
	EndDo;
		
	If PropertiesContent = "SearchProperties" Or StageNumber = 1 Then
		// Tabular sections are converted only after the OCR handler.
		Return;
	EndIf;
		
	For Each CWT IN ConversionRule.TabularSectionsProperties Do
		
		If ReceivedData.AdditionalProperties.Property(CWT.Key) Then
			
			StructuresWithRowsDataArray = ReceivedData.AdditionalProperties[CWT.Key];
			For LineNumber = 1 To StructuresWithRowsDataArray.Count() Do
				
				StructureWithDataRows = StructuresWithRowsDataArray[LineNumber - 1];
				
				If StageNumber = 2 Then
					TSRow = ReceivedData[CWT.Key].Add();
				EndIf;
				
				For Each PCR IN CWT.Value Do
					
					XDTOObjectStructurePropertyConversion(
						ExchangeComponents,
						XDTOData,
						ReceivedData.AdditionalProperties,
						TSRow,
						PCR,
						StageNumber);
					
				EndDo;
				
			EndDo;
			
		Else
			Continue;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure XDTOObjectStructurePropertyConversion(
		ExchangeComponents,
		XDTOData,
		AdditionalProperties,
		DataReceiver,
		PCR,
		StageNumber = 1)
	// PCR with only format propety is processed - it is used only during the export.
	If TrimAll(PCR.ConfigurationProperty) = "" Then
		Return;
	EndIf;
		
	PropertyConversionRule = PCR.PropertyConversionRule;
	
	If StageNumber = 1 Then
		
		If Not ValueIsFilled(PCR.FormatProperty) Then
			Return;
		EndIf;
		
		If PCR.KeyPropertiesProcessing
			AND Not XDTOData.Property("IsKeyPropertiesSet") Then
			DataSource = XDTOData.KeyProperties;
		Else
			DataSource = XDTOData;
		EndIf;
		
		If DataSource.Property(PCR.FormatProperty) Then
			PropertyValue = DataSource[PCR.FormatProperty];
		EndIf;
		
	ElsIf StageNumber = 2 Then
		
		If StageNumber = 2 AND Not PCR.UsedConversionAlgorithm Then
			Return;
		EndIf;
		
		// At the 2nd stage values properties are obtained from the additional
		// properties of the obtained data object and represent a structure that contains either instruction for converting or the XDTO value.
		// If the value receiver is a row of tabular section,
		// the property value is located in AdditionalValues [TabularSectionName][RowIndex].
		If ValueIsFilled(PCR.TSName) Then
			DataSource = AdditionalProperties[PCR.TSName][DataReceiver.LineNumber - 1];
		Else
			DataSource = AdditionalProperties;
		EndIf;
		
		If DataSource.Property(PCR.ConfigurationProperty) Then
			PropertyValue = DataSource[PCR.ConfigurationProperty];
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(PropertyValue) Then
		Return;
	EndIf;
	
	// Value is an instruction.
	If TypeOf(PropertyValue) = Type("Structure")
		AND PropertyValue.Count() < 3 Then
		
		If PropertyValue.Property("OCRName") Then
			PropertyConversionRule = PropertyValue.OCRName;
		EndIf;
		
		If PropertyValue.Property("Value") Then
			PropertyValue = PropertyValue.Value;
		EndIf;
		
	EndIf;
	
	If TypeOf(PropertyValue) = Type("Structure") Then
		
		PDCR = ExchangeComponents.PredefinedDataConversionRules.Find(PropertyConversionRule, "PDCRName");
		If PDCR <> Undefined Then
			
			Value = PDCR.ValueConversionsOnReceive.Get(PropertyValue.Value);
			DataReceiver[PCR.ConfigurationProperty] = Value;
			Return;
			
		Else
			PropertyConversionRule = OCRByName(ExchangeComponents, PropertyConversionRule);
		EndIf;
	Else
		// Conversion of simple properties perform only at the 1st stage.
		DataReceiver[PCR.ConfigurationProperty] = PropertyValue;
		Return;
	EndIf;
	
	DataForEIBWrite = XDTOObjectStructureInIBData(ExchangeComponents, PropertyValue, PropertyConversionRule, "GetRef");
	
	DataReceiver[PCR.ConfigurationProperty] = DataForEIBWrite.Ref;
	
EndProcedure

Function ObjectRefByXDTOObjectProperties(ConversionRule, ReceivedData)
	
	Result = Undefined;
	// ConversionRule.ObjectSearchFields - array, contains different
	//	search variants array items - table of values with the search fields.
	If ConversionRule.SearchFields = Undefined OR
		TypeOf(ConversionRule.SearchFields) <> Type("Array") Then
		Return Result;
	EndIf;
	
	For Each SearchTry IN ConversionRule.SearchFields Do
		SearchFields = New Structure(SearchTry);
		FillPropertyValues(SearchFields, ReceivedData);

		If ConversionRule.ThisIsDocument
			AND SearchFields.Count() = 2
			AND SearchFields.Property("Date")
			AND SearchFields.Property("Number")
			Then
			
			Result = ConversionRule.ObjectManager.FindByNumber(SearchFields.Number, SearchFields.Date);
			
			Result = ?(Result.IsEmpty(), Undefined, Result);
		ElsIf ConversionRule.ThisIsCatalog
			AND SearchFields.Count() = 1
			AND SearchFields.Property("Description") Then
			Result = ConversionRule.ObjectManager.FindByDescription(SearchFields.Description);
		ElsIf ConversionRule.ThisIsCatalog
			AND SearchFields.Count() = 1
			AND SearchFields.Property("Code") Then
			Result = ConversionRule.ObjectManager.FindByCode(SearchFields.Code);
		Else
			Query = New Query;
			
			QueryText =
			"SELECT
			|	Table.Ref AS Ref
			|FROM
			|	[DescriptionFull] AS Table
			|WHERE
			|	[FilterCondition]";
			
			Filter = New Array;
			
			For Each AfterSearch IN SearchFields Do
				
				Query.SetParameter(AfterSearch.Key, AfterSearch.Value);
				
				Filter.Add(StrReplace("Table.[Key] = &[Key]", "[Key]", AfterSearch.Key));
				
			EndDo;
			
			FilterCondition = StringFunctionsClientServer.RowFromArraySubrows(Filter, " AND ");
			QueryText = StrReplace(QueryText, "[FilterCondition]", FilterCondition);
			QueryText = StrReplace(QueryText, "[DescriptionFull]", ConversionRule.DescriptionFull);
			Query.Text = QueryText;
			
			QueryResult = Query.Execute();
			
			If Not QueryResult.IsEmpty() Then
				
				Selection = QueryResult.Select();
				Selection.Next();
				
				Result = Selection.Ref;
				
			EndIf;
			
		EndIf;
		If ValueIsFilled(Result) Then
			Break;
		EndIf;
	EndDo;
	Return Result;
EndFunction

Procedure FillIBDataByReceivedData(IBData, ReceivedData, ConversionRule)
	
	FieldsCopies = ConversionRule.Properties.UnloadColumn("ConfigurationProperty");
	If FieldsCopies.Count() > 0 Then
		FieldsCopies = StringFunctionsClientServer.RowFromArraySubrows(FieldsCopies, ",", True);
		FillPropertyValues(IBData, ReceivedData, FieldsCopies);
	EndIf;
	
	For Each TabularSection IN ConversionRule.TabularSectionsProperties Do
		IBData[TabularSection.Key].Clear();
		IBData[TabularSection.Key].Load(ReceivedData[TabularSection.Key].Unload());
	EndDo;
EndProcedure

Function InitializeReceivedData(ConversionRule)
	
	If ConversionRule.ThisIsDocument Then
		ReceivedData = ConversionRule.ObjectManager.CreateDocument();
	ElsIf ConversionRule.ThisIsCatalog
		Or ConversionRule.ThisIsChartOfCharacteristicTypes Then
		If ConversionRule.RuleForCatalogGroup Then
			ReceivedData = ConversionRule.ObjectManager.CreateFolder();
		Else
			ReceivedData = ConversionRule.ObjectManager.CreateItem();
		EndIf;
	EndIf;
	
	Return ReceivedData
	
EndFunction

#EndRegion

#EndRegion

#Region ImportTP

Function MatchOldAndNewTPData(ObjectTabularSectionArterProcessing, ObjectTabularSectionBeforeProcessing, KeyFieldsArray)
	
	NewTPRowsAndOldTPRowsMatch = New Map;
	
	For Each NewTPRow IN ObjectTabularSectionArterProcessing Do
		
		OldTPFoundString = Undefined;
		
		SearchStructure = New Structure;
		For Each KeyField IN KeyFieldsArray Do
			SearchStructure.Insert(KeyField, NewTPRow[KeyField]);
		EndDo;
		
		NewTPFoundStrings = ObjectTabularSectionArterProcessing.FindRows(SearchStructure);
		
		If NewTPFoundStrings.Count() = 1 Then
			
			OldTPFoundStrings = ObjectTabularSectionBeforeProcessing.FindRows(SearchStructure);
			
			If OldTPFoundStrings.Count() = 1 Then
				OldTPFoundString = OldTPFoundStrings[0];
			EndIf;
			
		EndIf;
		
		NewTPRowsAndOldTPRowsMatch.Insert(NewTPRow, OldTPFoundString);
		
	EndDo;
	
	Return NewTPRowsAndOldTPRowsMatch;
	
EndFunction

// The procedure fills in the tabular section of an object taking into account the previous version of tabular section (before data import).
//
// Parameters:
//  ObjectTabularSectionArterProcessing - Tabular section which contains changed data.
//  ObjectTabularSectionBeforeProcessing    - Vales table, the content of the object tabular section before data import.
//  KeyFields                        - Columns according to which the rows are searched in
//                                        the tabular section (row by comma).
//  ColumnsForInclusion                 - Other columns (except for the key ones) with changing values (row separated by comma).
//  ColumnsForExclusion                - Columns without changing the values (row by comma).
//
Procedure FillObjectTabularSectionWithInitialData(
	ObjectTabularSectionArterProcessing, 
	ObjectTabularSectionBeforeProcessing,
	Val KeyFields = "",
	ColumnsForInclusion = "", 
	ColumnsForExclusion = "") Export
	
	If TypeOf(KeyFields) = Type("String") Then
		If KeyFields = "" Then
			Return; // You can not get the match of old and new data without key fields.
		Else
			KeyFields = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(KeyFields, ",");
		EndIf;
	EndIf;
	
	MatchOldAndNewTPData = MatchOldAndNewTPData(
		ObjectTabularSectionArterProcessing, 
		ObjectTabularSectionBeforeProcessing,
		KeyFields);
	
	For Each NewTPRow IN ObjectTabularSectionArterProcessing Do
		OldTPCode = MatchOldAndNewTPData.Get(NewTPRow);
		If OldTPCode <> Undefined Then
			FillPropertyValues(NewTPRow, OldTPCode, ColumnsForInclusion, ColumnsForExclusion);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure DoNumberCodeGenerationIfNeeded(Object)
	
	ObjectTypeName = CommonUse.ObjectKindByKind(TypeOf(Object.Ref));
	
	// Look if quantity or number is filled by type of document.
	If ObjectTypeName = "Document"
		OR ObjectTypeName = "BusinessProcess"
		OR ObjectTypeName = "Task" Then
		
		If Not ValueIsFilled(Object.Number) Then
			
			Object.SetNewNumber();
			
		EndIf;
		
	ElsIf ObjectTypeName = "Catalog"
		OR ObjectTypeName = "ChartOfCharacteristicTypes"
		OR ObjectTypeName = "ExchangePlan" Then
		
		If Not ValueIsFilled(Object.Code) Then
			
			Object.SetNewCode();
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure RemoveDeletionMarkFromPredefinedItem(Object, ObjectType, ExchangeComponents)
	
	Try
		DeletionMark = Object.DeletionMark;
	Except
		DeletionMark = False;
	EndTry;
	
	If DeletionMark Then
		
		Try
			Predefined = Object.Predefined;
		Except
			Predefined = False;
		EndTry;
		
		If Predefined Then
			
			Object.DeletionMark = False;
			
			// note event in the RL
			LR            = GetProtocolRecordStructure(80);
			LR.ObjectType = ObjectType;
			LR.Object     = String(Object);
			
			ExchangeComponents.DataExchangeStatus.ExchangeProcessResult =
				Enums.ExchangeExecutionResult.CompletedWithWarnings;
			WriteInExecutionProtocol(ExchangeComponents, 80, LR, False);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PostponedOperations
Procedure RememberObjectForPendingFilling(DataForEIBWrite, ConversionRule, ExchangeComponents)
	
	If ConversionRule.HasHandlerAfterAllDataImport Then
		
		// Input the data about an object to the table of delayed processing.
		NewRow = ExchangeComponents.ImportedObjects.Add();
		NewRow.HandlerName = ConversionRule.AfterAllDataImport;
		NewRow.Object = DataForEIBWrite;
		
	EndIf;
	
EndProcedure

Procedure DelayedObjectsFilling(ExchangeComponents)
	
	ConversionParameters = ExchangeComponents.ConversionParameters;
	ImportedObjects = ExchangeComponents.ImportedObjects;
	
	ExchangeComponents.ExchangeManager.BeforeDelayedFilling(ExchangeComponents);
	
	For Each TableRow IN ImportedObjects Do
		
		If TableRow.Object.IsNew() Then
			Continue;
		EndIf;
		
		Object = TableRow.Object.Ref.GetObject();
		
		// Transfer of the additional values.
		For Each Property IN TableRow.Object.AdditionalProperties Do
			Object.AdditionalProperties.Insert(Property.Key, Property.Value);
		EndDo;
		
		HandlerName = TableRow.HandlerName;
		
		ExchangeManager = ExchangeComponents.ExchangeManager;
		ParametersStructure = New Structure();
		ParametersStructure.Insert("Object", Object);
		ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);
		ParametersStructure.Insert("ObjectModified", True);

		Try
			ExchangeManager.ExecuteModuleManagerProcedure(HandlerName, ParametersStructure);
		Except
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Error executing the AfterAllDataConversion handler.
		|Source type:
		|%1 Error description: %2';ru='Ошибка выполнения обработчика ПослеКонвертацииВсехДанных.
		|Тип
		|источника: %1 Описание ошибки: %2'"),
				String(Object),
				DetailErrorDescription(ErrorInfo())
			);
		EndTry;
		
		ObjectModified = ParametersStructure.ObjectModified;
		
		If ObjectModified Then
			SetDataExchangeImport(Object, True, False, ExchangeComponents.CorrespondentNode);
			Object.Write();
		EndIf;
		
	EndDo;

EndProcedure

Procedure PerformPostponedObjectsRecording(ExchangeComponents)
	
	If ExchangeComponents.ObjectsForPostponedRecording.Count() = 0 Then
		Return // No objects in the queue
	EndIf;
	
	For Each MappingObject IN ExchangeComponents.ObjectsForPostponedRecording Do
		
		If MappingObject.Key.IsEmpty() Then
			Continue;
		EndIf;
		
		Object = MappingObject.Key.GetObject();
		
		If Object = Undefined Then
			Continue;
		EndIf;
		
		// Set a sender node to prevent the object from being registered on the node for which importing is run, posting should not be in the import mode.
		SetDataExchangeImport(Object, False, False, ExchangeComponents.CorrespondentNode);
		
		ErrorDescription = "";
		ObjectSuccessfulyRecorded = False;
		
		Try
			
			AdditionalProperties = MappingObject.Value;
			
			For Each Property IN AdditionalProperties Do
				
				Object.AdditionalProperties.Insert(Property.Key, Property.Value);
				
			EndDo;
			
			Object.AdditionalProperties.Insert("WriteBack");
			
			If Object.CheckFilling() Then
				
				// When you post the document, remove a
				// ban on the PRO execution as PRO were ignored during the regular write to optimize the speed of the data import.
				If Object.AdditionalProperties.Property("DisableObjectChangeRecordMechanism") Then
					Object.AdditionalProperties.Delete("DisableObjectChangeRecordMechanism");
				EndIf;
				
				DataExchangeServer.SkipChangeProhibitionCheck();
				Object.AdditionalProperties.Insert("SkipChangeProhibitionCheck");
				
				InfoAboutObjectVersion = New Structure;
				InfoAboutObjectVersion.Insert("PostponedProcessing", True);
				InfoAboutObjectVersion.Insert("ObjectVersioningType", "ChangedByUser");
				InfoAboutObjectVersion.Insert("VersionAuthor", ExchangeComponents.CorrespondentNode);
				Object.AdditionalProperties.Insert("InfoAboutObjectVersion", InfoAboutObjectVersion);
				
				// Try to write the object.
				Object.Write();
				
				ObjectSuccessfulyRecorded = True;
				
			Else
				
				ObjectSuccessfulyRecorded = False;
				
				ErrorDescription = NStr("en='An error occurred when checking the attribute population';ru='Ошибка проверки заполнения реквизитов'");
				
			EndIf;
			
		Except
			
			ErrorDescription = BriefErrorDescription(ErrorInfo());
			
			ObjectSuccessfulyRecorded = False;
			
		EndTry;
		
		DataExchangeServer.SkipChangeProhibitionCheck(False);
		
		If Not ObjectSuccessfulyRecorded Then
			
			DataExchangeServer.RegisterErrorRecordsObject(Object, ExchangeComponents.CorrespondentNode, ErrorDescription);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Other

Function ArrangeExchangeFormat(Val ExchangeFormat)
	
	Result = New Structure("BasicFormat, Version");
	
	FormatItems = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ExchangeFormat, "/");
	
	If FormatItems.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Non-canonical name of the exchange format <%1>';ru='Неканоническое имя формата обмена <%1>'"),
			ExchangeFormat
		);
	EndIf;
	
	Result.Version = FormatItems[FormatItems.UBound()];
	
	CheckVersion(Result.Version);
	
	FormatItems.Delete(FormatItems.UBound());
	
	Result.BasicFormat = StringFunctionsClientServer.RowFromArraySubrows(FormatItems, "/");
	
	Return Result;
EndFunction

Function RefByUDID(IBObjectValueType, XDTOObjectUDID)
	
	TypeArray = New Array;
	TypeArray.Add(IBObjectValueType);
	TypeDescription = New TypeDescription(TypeArray);
	EmptyRef = TypeDescription.AdjustValue();

	MetadataObjectManager = CommonUse.ObjectManagerByRef(EmptyRef);
	
	Return MetadataObjectManager.GetRef(New UUID(XDTOObjectUDID));
	
EndFunction

Function FindRefbyPublicIdidentifier(XDTOObjectUDID, ExchangeComponents, IBObjectValueType)
	
	Query = New Query("
		|SELECT
		|	Refs
		|FROM InformationRegister.SynchronizedObjectPublicIDs
		|WHERE InfobaseNode = &InfobaseNode AND
		|	ID = &ID");
	Query.SetParameter("InfobaseNode", ExchangeComponents.CorrespondentNode);
	Query.SetParameter("ID", XDTOObjectUDID);
	Selection = Query.Execute().Select();
	If Selection.Count() > 0 Then
		SuitableTypeRefsQuantity = 0;
		FoundReference = Undefined;
		While Selection.Next() Do
			If TypeOf(Selection.Ref) = IBObjectValueType Then
				FoundReference = Selection.Ref;
				SuitableTypeRefsQuantity = SuitableTypeRefsQuantity + 1;
				If SuitableTypeRefsQuantity > 1 Then
					Break;
				EndIf;
			EndIf;
		EndDo;
		If  SuitableTypeRefsQuantity > 1 Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Several links are assigned for unique identifier <%1> and node <%2>.';ru='Для уникального идентификатора <%1> и узла <%2> назначено несколько ссылок.'"),
				String(XDTOObjectUDID), String(ExchangeComponents.CorrespondentNode)
				);
		Else
			Return FoundReference;
		EndIf;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Read and process data on document deletion.
//
// Parameters:
//  ExchangeComponents        - Structure - contains all rules and parameters of exchange
//  XDTODataObject              - Object of the XDTO ObjectRemoval package which contains information
//                            about the removed object from the infobase.
//  ObjectsArrayForDeletion - An array with a reference to an object for removal.
//                            The objects are actually deleted after all data has been
//                            imported, considering which objects were imported (don't delete refs that were imported
//                            as other XDTOObjects).
//
Procedure ReadDeletion(ExchangeComponents, XDTODataObject, ObjectsArrayForDeletion, TableToImport=Undefined) Export
	
	XDTORefType = Undefined;
	
	If Not XDTODataObject.IsSet("ObjectReference") Then
		Return;
	EndIf;
	
	For Each XDTOProperty IN XDTODataObject.ObjectReference.ObjectReference.Properties() Do
		
		If Not XDTODataObject.ObjectReference.ObjectReference.IsSet(XDTOProperty) Then
			Continue;
		EndIf;
		XDTOPropertyValue = XDTODataObject.ObjectReference.ObjectReference.GetXDTO(XDTOProperty);
		XDTORefValue = ReadCompoundTypeXDTOValue(XDTOPropertyValue, "Ref");
		// Define reference type
		XDTORefType = XDTORefValue.XDTOValueType;
		UUIDString = XDTORefValue.Value;
		Break;
		
	EndDo;
	
	If XDTORefType = Undefined Then
		Return;
	EndIf;
	
	// Search OCR
	DCR = DERByXDTORefsType(ExchangeComponents, XDTORefType, True);
	
	If ValueIsFilled(DCR) Then
		
		OCRNameArray = DCR.UsedOCR;
		
		For Each ConversionRuleName IN OCRNameArray Do
			
			ConversionRule = ExchangeComponents.ObjectConversionRules.Find(ConversionRuleName, "OCRName");
			If ConversionRule.IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields"
				Or ConversionRule.IdentificationVariant = "ByUniqueIdidentificator" Then
				
				If TableToImport <> Undefined Then
					ObjectTypeAsString = ConversionRule.ReceivedDataTypeRow;
					
					SourceTypeAsString = XDTODataObject.Type().Name;
					ReceiverTypeAsString = ConversionRule.ReceivedDataTypeRow;
					
					DataTableKey = DataExchangeServer.DataTableKey(SourceTypeAsString, ReceiverTypeAsString, False);
					
					If TableToImport.Find(DataTableKey) = Undefined Then
						Continue;
					EndIf;
				EndIf;
				
				ObjectsArrayForDeletion.Add(XDTOObjectObjectRefByUDID(UUIDString, ConversionRule.DataType, ExchangeComponents));
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure ApplyObjectDeletion(ExchangeComponents, ObjectsArrayForDeletion, ImportedObjectsArray)
	
	For Each ImportedObject IN ImportedObjectsArray Do
		While ObjectsArrayForDeletion.Find(ImportedObject) <> Undefined Do
			ObjectsArrayForDeletion.Delete(ObjectsArrayForDeletion.Find(ImportedObject));
		EndDo;
	EndDo;
	
	For Each ItemToDelete IN ObjectsArrayForDeletion Do
		
		// Actually delete references
		Object = ItemToDelete.GetObject();
		If Object = Undefined Then
			Continue;
		EndIf;
		
		If ExchangeComponents.DataImportToInformationBaseMode Then
			If Metadata.Documents.Contains(Object.Metadata()) AND Object.Posted Then
				UndoObjectPostingInIB(Object, ExchangeComponents.CorrespondentNode);
			EndIf;
			DeleteObject(Object, False);
		Else
			
			ReceivedDataTypeRow = DataTypeNameByMetadataObject(Object.Metadata(), False, False);
			
			TableRow = ExchangeComponents.DataTableOfPackageHeader.Add();
			
			TableRow.ObjectTypeAsString =ReceivedDataTypeRow;
			TableRow.ObjectsCountInSource = 1;
			TableRow.ReceiverTypeAsString = ReceivedDataTypeRow;
			TableRow.ThisIsObjectDeletion = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DeleteObject(Object, DeleteDirectly)
	
	Try
		
		Predefined = Object.Predefined;
		
	Except
		
		Predefined = False;
		
	EndTry;
	
	If Predefined Then
		
		Return;
		
	EndIf;
	
	If DeleteDirectly Then
		
		Object.Delete();
		
	Else
		
		SetObjectDeletionMark(Object);
		
	EndIf;
	
EndProcedure

// Sets deletion mark.
//
// Parameters:
//  Object          - Object to set a mark.
//  DeletionMark - Boolean - Check box of the deletion mark.
//  ObjectTypeName  - String - String object type.
//
Procedure SetObjectDeletionMark(Object)
	
	If Object.AdditionalProperties.Property("DataImportProhibitionFound") Then
		Return;
	EndIf;
	
	SetDataExchangeImport(Object);
	
	// For hierarchical objects mark as deleted only a specific object.
	BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(Object.Metadata());
	If BaseTypeName = "Catalogs"
		Or BaseTypeName = "ChartsOfCharacteristicTypes"
		Or BaseTypeName = "ChartsOfAccounts" Then
		Object.SetDeletionMark(True, False);
	Else
		Object.SetDeletionMark(True);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region ExchangeRulesSearch

Function DERByXDTORefsType(ExchangeComponents, XDTORefType, ReturnEmptyValue = False)
	
	DataProcessorRule = ExchangeComponents.DataProcessingRules.Find(XDTORefType, "XDTORefType");
	If DataProcessorRule = Undefined Then
		
		If ReturnEmptyValue Then
			Return DataProcessorRule;
		Else
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='DER for XDTO reference type is not found.
		|XDTO reference type:
		|%1 Error description: %2';ru='Не найдено ПОД для типа ссылки XDTO.
		|Тип ссылки
		|XDTO: %1 Описание ошибки: %2'"),
				String(XDTORefType),
				DetailErrorDescription(ErrorInfo())
				);
				
		EndIf;
		
	Else
		Return DataProcessorRule;
	EndIf;
	
EndFunction

Function DERByXDTOObjectType(ExchangeComponents, XDTOObjectType, ReturnEmptyValue = False)
	
	DataProcessorRule = ExchangeComponents.DataProcessingRules.Find(XDTOObjectType, "SelectionObjectFormat");
	If DataProcessorRule = Undefined Then
		
		If ReturnEmptyValue Then
			Return DataProcessorRule;
		Else
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='DER for XDTO object type is not found.
		|XDTO object type:
		|%1 Error description: %2';ru='Не найдено ПОД для типа объекта XDTO.
		|Тип объекта
		|XDTO: %1 Описание ошибки: %2'"),
				String(XDTOObjectType),
				DetailErrorDescription(ErrorInfo())
				);
				
		EndIf;
		
	Else
		Return DataProcessorRule;
	EndIf;
	
EndFunction

Function DERByMetadataObject(ExchangeComponents, MetadataObject)
	
	DataProcessorRule = ExchangeComponents.DataProcessingRules.Find(MetadataObject, "SelectionObjectMetadata");
	
	If DataProcessorRule = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='DER for metadata objects is not found.
		|Metadata object: %1';ru='Не найдено ПОД для объекта метаданных.
		|Объект метаданных: %1'"),
			String(MetadataObject));
			
	Else
		Return DataProcessorRule;
	EndIf;

EndFunction

Function DERByName(ExchangeComponents, Name)
	
	DataProcessorRule = ExchangeComponents.DataProcessingRules.Find(Name, "Name");
	
	If DataProcessorRule = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='DER with name %1 is not found';ru='Не найдено ПОД с именем %1'"), Name);
			
	Else
		Return DataProcessorRule;
	EndIf;

EndFunction

#EndRegion

#Region ExchangeRulesEventsHandlers

#Region EventsHandlersDataProcessingRules
// Procedure - wrapper of the DER OnProcessing handler call.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//  DataProcessorRule - String of the data processing table which
//  corresponds to the processed POD ProcessingObject  - Reference to an object that needs to be processed, a structure that corresponds to the XDTO object (on import), or a reference to the infobase object (on export).

//  UseOCR - The structure that defines OCR of
//                     the exported object OCR keys
//                     correspond to the OCR names, values - shows that OCR for a specific processing object was used.
//
Procedure OnProcessDER(ExchangeComponents, DataProcessorRule, Val DataProcessorObject, UseOCR) Export

	ExchangeManager = ExchangeComponents.ExchangeManager;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("DataProcessorObject", DataProcessorObject);
	ParametersStructure.Insert("UseOCR", UseOCR);
	ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);

	Try
		ExchangeManager.ExecuteModuleManagerProcedure(DataProcessorRule.OnProcess, ParametersStructure);
	Except
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Error of the OnProcessing handler execution.
		|Object:
		|%1 Error description: %2';ru='Ошибка выполнения обработчика ПОД ПриОбработке.
		|Объект:
		|%1 Описание ошибки: %2'"),
			String(DataProcessorObject),
			DetailErrorDescription(ErrorInfo())
			);
	EndTry;
	
	DataProcessorObject  = ParametersStructure.DataProcessorObject;
	UseOCR = ParametersStructure.UseOCR;
	ExchangeComponents = ParametersStructure.ExchangeComponents;
	
EndProcedure

// Function - wrapper of the DER DataSelection handler call.
//
// Parameters:
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//  DataProcessorRule - Table row of the data processing rules corresponding to the processed POD
//
// Returns - something that will return the DataSelection handler (for example, query result selection).
//
Function DataSelection(ExchangeComponents, DataProcessorRule) Export
	
	SamplingAlgorithm = DataProcessorRule.DataSelection;
	If ValueIsFilled(SamplingAlgorithm) Then
		
		ExchangeManager = ExchangeComponents.ExchangeManager;
		ParametersStructure = New Structure();
		ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);
		
		Try
			DataSelection = ExchangeManager.ExecuteManagerModuleFunction(DataProcessorRule.DataSelection, ParametersStructure);
		Except
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Error during the execution of the DER DataSelection handler.
		|DER name:
		|%1 Error description: %2';ru='Ошибка выполнения обработчика ПОД ВыборкаДанных.
		|Имя
		|ПОД: %1 Описание ошибки: %2'"),
					DataProcessorRule.Name,
					DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	Else
		Query = New Query;
		Query.Text = 
		"SELECT
		|	Refs
		|FROM
		|	" + DataProcessorRule.SelectionTableName;
		
		DataSelection = Query.Execute().Unload().UnloadColumn("Ref");
	EndIf;
	
	Return DataSelection;
	
EndFunction

#EndRegion

#Region ConversionRulesEventsHandlers
// Function - wrapper of the OCR OnSendData handler call.
//
// Parameters:
//  IBData         - Reference to the exported object of the infobase.
//                     May also have the structure of key properties if a reference is exported, not an object.
//  XDTOData       - Structure, to which the data is exported. The content is identical to the XDTO object.
//  HandlerName   - String, name of the procedure-processor in the manager module.
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//  ExportStack     - An array contains references to the exported objects taking the inclusion into account.
//
Procedure OnDataSending(IBData, XDTOData, Val HandlerName, ExchangeComponents, ExportStack) Export
	ExchangeManager = ExchangeComponents.ExchangeManager;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("IBData", IBData);
	ParametersStructure.Insert("XDTOData", XDTOData);
	ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);
	ParametersStructure.Insert("ExportStack", ExportStack);

	Try
		ExchangeManager.ExecuteModuleManagerProcedure(HandlerName, ParametersStructure);
	Except
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Error of the OnSendData handler.
		|Object:
		|%1 Error description: %2';ru='Ошибка выполнения обработчика ПриОтправкеДанных.
		|Объект:
		|%1 Описание ошибки: %2'"),
			String(IBData),
			DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
	XDTOData       = ParametersStructure.XDTOData;
	ExchangeComponents = ParametersStructure.ExchangeComponents;
	ExportStack     = ParametersStructure.ExportStack;
	
EndProcedure

// Function - wrapper of the OCR OnConvertXDTOData handler  call.
//
// Parameters:
//  ReceivedData - Object of the infobase where the data is being imported.
//  XDTOData       - Structure, from which the data is imported. The content is identical to the imported XDTO object.
//  ExchangeComponents - Structure - contains all rules and parameters of exchange
//  HandlerName   - String, name of the procedure-processor in the manager module.
//
Procedure OnConvertXDTOData(XDTOData, ReceivedData, ExchangeComponents, Val HandlerName) Export
	
	ExchangeManager = ExchangeComponents.ExchangeManager;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("XDTOData", XDTOData);
	ParametersStructure.Insert("ReceivedData", ReceivedData);
	ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);

	Try
		ExchangeManager.ExecuteModuleManagerProcedure(HandlerName, ParametersStructure);
	Except
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Error performing the OnConvertXDTOData handler.
		|Source type:
		|%1 Error description: %2';ru='Ошибка выполнения обработчика ПриКонвертацииДанныхXDTO.
		|Тип
		|источника: %1 Описание ошибки: %2'"),
			String(XDTOData),
			DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
	XDTOData               = ParametersStructure.XDTOData;
	ReceivedData         = ParametersStructure.ReceivedData;
	ExchangeComponents         = ParametersStructure.ExchangeComponents;
	
EndProcedure

// Function - wrapper of the OCR BeforeReceivedDataWrite handler call.
//
// Parameters:
//  ReceivedData   - Object of the infobase where the data is being imported.
//  IBData           - Object of the infobase which was found during the identification of the exported data. 
//                       If the object corresponding to the imported one is not found, IBData = Undefined.
//  ExchangeComponents   - Structure - contains all rules and parameters of exchange
//  HandlerName     - String, name of the procedure-processor in the manager module.
//  PropertiesConversion - Table of values, rules of the object properties conversion.
//                       Used to define the content of properties which need
//                       to be transferred from ReceivedData to IBData.
//
Procedure BeforeReceivedDataWrite(ReceivedData, IBData, ExchangeComponents, HandlerName, PropertiesConversion) Export
	
	ExchangeManager = ExchangeComponents.ExchangeManager;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("IBData", IBData);
	ParametersStructure.Insert("ReceivedData", ReceivedData);
	ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);
	ParametersStructure.Insert("PropertiesConversion", PropertiesConversion);

	Try
		ExchangeManager.ExecuteModuleManagerProcedure(HandlerName, ParametersStructure);
	Except
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Error performing the BeforeReceivedDataWrite handler.
		|Object:
		|%1 Error description: %2';ru='Ошибка выполнения обработчика ПередЗаписьюПолученныхДанных.
		|Объект:
		|%1 Описание ошибки: %2'"),
			String(IBData),
			DetailErrorDescription(ErrorInfo())
		);
	EndTry;
	
	IBData                 = ParametersStructure.IBData;
	ReceivedData         = ParametersStructure.ReceivedData;
	ExchangeComponents         = ParametersStructure.ExchangeComponents;
	PropertiesConversion       = ParametersStructure.PropertiesConversion;
	
EndProcedure

#EndRegion

#EndRegion

#Region ProtocolIntroduction

// Returns the structure type object containing
// all possible fields of the execution protocol record (error messages etc.).
//
// Parameters:
//  PErrorMessages - String, contains the error code.
//  ErrorString        - String, contains a module row with an error.
//
// Returns:
//  Object of the structure type
// 
Function GetProtocolRecordStructure(PErrorMessages = "", Val ErrorString = "")

	ErrorStructure = New Structure();
	ErrorStructure.Insert("OCRName");
	ErrorStructure.Insert("DERName");
	ErrorStructure.Insert("NPP");
	ErrorStructure.Insert("GSn");
	ErrorStructure.Insert("Source");
	ErrorStructure.Insert("ObjectType");
	ErrorStructure.Insert("Property");
	ErrorStructure.Insert("Value");
	ErrorStructure.Insert("ValueType");
	ErrorStructure.Insert("OCR");
	ErrorStructure.Insert("PCR");
	ErrorStructure.Insert("PGCR");
	ErrorStructure.Insert("DER");
	ErrorStructure.Insert("DCR");
	ErrorStructure.Insert("Object");
	ErrorStructure.Insert("TargetProperty");
	ErrorStructure.Insert("ConvertedValue");
	ErrorStructure.Insert("Handler");
	ErrorStructure.Insert("ErrorDescription");
	ErrorStructure.Insert("ModulePosition");
	ErrorStructure.Insert("Text");
	ErrorStructure.Insert("PErrorMessages");
	ErrorStructure.Insert("ExchangePlanNode");
	
	ModuleString              = SeparateBySeparator(ErrorString, "{");
	ErrorDescription            = SeparateBySeparator(ModuleString, "}: ");
	
	If ErrorDescription <> "" Then
		
		ErrorStructure.ErrorDescription         = ErrorDescription;
		ErrorStructure.ModulePosition          = ModuleString;
				
	EndIf;
	
	If ErrorStructure.PErrorMessages <> "" Then
		
		ErrorStructure.PErrorMessages           = PErrorMessages;
		
	EndIf;
	
	Return ErrorStructure;
	
EndFunction 

Procedure WriteInformationAboutErrorToProtocol(PErrorMessages, ErrorString, Object, ExchangeComponents, ObjectType = Undefined)
	
	LR         = GetProtocolRecordStructure(PErrorMessages, ErrorString);
	LR.Object  = Object;
	
	If ObjectType <> Undefined Then
		LR.ObjectType     = ObjectType;
	EndIf;
	
	WriteInExecutionProtocol(ExchangeComponents, PErrorMessages, LR);
	
EndProcedure

Function ExchangeProcessResultError(ExchangeProcessResult)
	
	Return ExchangeProcessResult = Enums.ExchangeExecutionResult.Error
		Or ExchangeProcessResult = Enums.ExchangeExecutionResult.Error_MessageTransport;
	
EndFunction

Function ExchangeProcessResultDoMessageBox(ExchangeProcessResult)
	
	Return ExchangeProcessResult = Enums.ExchangeExecutionResult.CompletedWithWarnings
		Or ExchangeProcessResult = Enums.ExchangeExecutionResult.Warning_ExchangeMessageHasBeenPreviouslyReceived;
	
EndFunction

#EndRegion

#Region ExchangeFormatVersioningProceduresAndFunctions

Function ExchangeFormatVersions(Val InfobaseNode)
	
	ExchangeFormatVersions = New Map;
	
	ExchangePlanManager(InfobaseNode).GetExchangeFormatVersions(ExchangeFormatVersions);
	
	If ExchangeFormatVersions.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Versions of the exchange format are not specified.
		|Names of an
		|exchange plan: %1 Procedure: GetAllExchangeFormatVersions(<ExchangeFormatVersions>)';ru='Не заданы версии формата обмена.
		|Имя
		|плана обмена: %1 Процедура: ПолучитьВерсииФорматаОбмена(<ВерсииФорматаОбмена>)'"),
			InfobaseNode.Metadata().Name
		);
	EndIf;
	
	Result = New Map;
	
	For Each Version IN ExchangeFormatVersions Do
		
		Result.Insert(TrimAll(Version.Key), Version.Value);
		
	EndDo;
	
	Return Result;
EndFunction

Function SortFormatVersions(Val FormatVersions)
	
	Result = New ValueTable;
	Result.Columns.Add("Version");
	
	For Each Version IN FormatVersions Do
		
		Result.Add().Version = Version.Key;
		
	EndDo;
	
	Result.Sort("Version Desc");
	
	Return Result.UnloadColumn("Version");
EndFunction

Procedure CheckVersion(Val Version)
	
	Versions = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Version, ".");
	
	If Versions.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Non-canonical presentation of the exchange format version: <%1>.';ru='Неканоническое представление версии формата обмена: <%1>.'"),
			Version
		);
	EndIf;
	
EndProcedure

Function MinExchangeFormatVersion(Val InfobaseNode)
	
	Result = Undefined;
	
	FormatVersions = ExchangeFormatVersions(InfobaseNode);
	
	For Each FormatVersion IN FormatVersions Do
		
		If Result = Undefined Then
			Result = FormatVersion.Key;
			Continue;
		EndIf;
		If CompareVersions(TrimAll(Result), TrimAll(FormatVersion.Key)) > 0 Then
			Result = FormatVersion.Key;
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// Receives an array of the exchange format versions sorted by descending.
// Parameters:
//  InfobaseNode - reference to the node-correspondent.
//
Function ExchangeFormatVersionsArray(Val InfobaseNode) Export
	
	Return SortFormatVersions(ExchangeFormatVersions(InfobaseNode));
	
EndFunction

#EndRegion

#Region Other

// Breaks a row into two parts: up to subrow and after.
//
// Parameters:
//  Str          - parsed row;
//  Delimiter  - subrow-separator:
//  Mode        - 0 - a separator in the returned subrows is not included;
//                 1 - separator is included into a left subrow;
//                 2 - separator is included to a right subrow.
//
// Returns:
//  Right part of the row - up to delimiter character
// 
Function SeparateBySeparator(Str, Val Delimiter, Mode=0)

	RightPart         = "";
	SplitterPos      = Find(Str, Delimiter);
	SeparatorLength    = StrLen(Delimiter);
	If SplitterPos > 0 Then
		RightPart	 = Mid(Str, SplitterPos + ?(Mode=2, 0, SeparatorLength));
		Str          = TrimAll(Left(Str, SplitterPos - ?(Mode=1, -SeparatorLength + 1, 1)));
	EndIf;

	Return(RightPart);

EndFunction // SeparateWithSeparator()

Function DataTypeNameByMetadataObject(Val MetadataObject, Val IsObject, Val ThisIsConstant)
	
	If ThisIsConstant = Undefined Then
		BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(MetadataObject);
		ThisIsConstant = (BaseTypeName = CommonUse.TypeNameConstants());
	EndIf;
	
	TypeLiterals = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(MetadataObject.FullName(), ".");
	
	If ThisIsConstant Then
		Result = "[TableType]ValueManager.[TableName]";
	Else
		If IsObject Then
			Result = "[TableType]Object.[TableName]";
		Else
			Result = "[TableType]Refs.[TableName]";
		EndIf;
	EndIf;
	
	Result = StrReplace(Result, "[TableType]", TypeLiterals[0]);
	Result = StrReplace(Result, "[TableName]", TypeLiterals[1]);
	Return Result;
EndFunction

// Procedure of removing the existing movements of the document during reposting (posting cancelation).
Procedure DeleteDocumentRegisterRecords(DocumentObject, Cancel)
	
	RecordTableRowToProcessArray = New Array();
	
	// Get the registers list which has movements on it.
	RegisterRecordTable = DefineIfThereAreRegisterRecordsByDocument(DocumentObject.Ref);
	RegisterRecordTable.Columns.Add("RecordSet");
	RegisterRecordTable.Columns.Add("ForceDelete", New TypeDescription("Boolean"));
		
	For Each RegisterRecordRow IN RegisterRecordTable Do
		// Register name is transferred as a value
		// received using the DescriptionFull function() of the register metadata.
		DotPosition = Find(RegisterRecordRow.Name, ".");
		TypeRegister = Left(RegisterRecordRow.Name, DotPosition - 1);
		RegisterName = TrimR(Mid(RegisterRecordRow.Name, DotPosition + 1));

		RecordTableRowToProcessArray.Add(RegisterRecordRow);
		
		If TypeRegister = "AccumulationRegister" Then
			SetMetadata = Metadata.AccumulationRegisters[RegisterName];
			Set = AccumulationRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "AccountingRegister" Then
			SetMetadata = Metadata.AccountingRegisters[RegisterName];
			Set = AccountingRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "InformationRegister" Then
			SetMetadata = Metadata.InformationRegisters[RegisterName];
			Set = InformationRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "CalculationRegister" Then
			SetMetadata = Metadata.CalculationRegisters[RegisterName];
			Set = CalculationRegisters[RegisterName].CreateRecordSet();
			
		EndIf;
		
		If Not AccessRight("Update", Set.Metadata()) Then
			// No rights to all register table.
			Raise NStr("en='Access right violation:';ru='Нарушение прав доступа:'") + " " + RegisterRecordRow.Name;
			Return;
		EndIf;

		Set.Filter.Recorder.Set(DocumentObject.Ref);

		// The set is not written immediately not to roll
		// back the transaction if later it turns out that you do not have enough rights for one of the registers.
		RegisterRecordRow.RecordSet = Set;
		
	EndDo;
	
	For Each RegisterRecordRow IN RecordTableRowToProcessArray Do		
		Try
			RegisterRecordRow.RecordSet.Write();
		Except
			// RlS or subsystem of the change prohibition date may have worked.
			Raise NStr("en='Operation failed:';ru='Операция не выполнена:'") + " " + RegisterRecordRow.Name
				+ Chars.LF + BriefErrorDescription(ErrorInfo());
		EndTry;
	EndDo;
	
	For Each RegisterRecord IN DocumentObject.RegisterRecords Do
		If RegisterRecord.Count() > 0 Then
			RegisterRecord.Clear();
		EndIf;
	EndDo;
	
	// Delete the registration records from all sequences.
	QueryText = "";
	For Each Sequence IN DocumentObject.BelongingToSequences Do
		// IN the query we get names of users, in which the document is registered.
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT """ + Sequence.Metadata().Name 
		+  """ AS Name IN " + Sequence.Metadata().FullName()  
		+ " WHERE Recorder = &Recorder";
		
	EndDo;
	
	If QueryText = "" Then
		RecordChangeTable = New ValueTable();
	Else
		Query = New Query(QueryText);
		Query.SetParameter("Recorder", DocumentObject.Ref);
		RecordChangeTable = Query.Execute().Unload();	
	EndIf;
	
	SequenceCollection = DocumentObject.BelongingToSequences;
	For Each SequenceRecordRecordSet IN SequenceCollection Do
		If (SequenceRecordRecordSet.Count() > 0)
			OR (NOT RecordChangeTable.Find(SequenceRecordRecordSet.Metadata().Name,"Name") = Undefined) Then
			SequenceRecordRecordSet.Clear();
		EndIf;
	EndDo;

EndProcedure

Function DefineIfThereAreRegisterRecordsByDocument(DocumentRef)
	QueryText = "";
	// To prevent the document drop in more than 256 tables.
	Counter_tables = 0;
	
	DocumentMetadata = DocumentRef.Metadata();
	
	If DocumentMetadata.RegisterRecords.Count() = 0 Then
		Return New ValueTable;
	EndIf;
	
	For Each RegisterRecord IN DocumentMetadata.RegisterRecords Do
		// IN the query, we get names of the registers which have
		// at
		// least one movement, for
		// example, SELECT
		// First 1 AccumulationRegister.ProductsInWarehouses FROM AccumulationRegister.ProductsInWarehouses WHERE Recorder = &Recorder
		
		// Register name equal to Row(200), see below.
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 CAST(""" + RegisterRecord.FullName() 
		+  """ AS String(200)) AS Name IN " + RegisterRecord.FullName() 
		+ " WHERE Recorder = &Recorder";
		
		// If the request has more than 256 tables - break it into
		// two parts (variant of a document with posting in 512 registers is unreal).
		Counter_tables = Counter_tables + 1;
		If Counter_tables = 256 Then
			Break;
		EndIf;
		
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("Recorder", DocumentRef);
	// During the export of the Name column the type is set according
	// to the longest row from the query, during the second pass through the table the
	// new name may not fit, that is why a row is immediately given in the query (200).
	QueryTable = Query.Execute().Unload();
	
	// If the number of tables is not more than 256 - return the table.
	If Counter_tables = DocumentMetadata.RegisterRecords.Count() Then
		Return QueryTable;			
	EndIf;
	
	// There are more than 256 tables, make an add. query and expand the rows of the table.
	
	QueryText = "";
	For Each RegisterRecord IN DocumentMetadata.RegisterRecords Do
		
		If Counter_tables > 0 Then
			Counter_tables = Counter_tables - 1;
			Continue;
		EndIf;
		
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 """ + RegisterRecord.FullName() +  """ AS Name IN " 
		+ RegisterRecord.FullName() + " WHERE Recorder = &Recorder";	
		
		
	EndDo;
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		TableRow = QueryTable.Add();
		FillPropertyValues(TableRow, Selection);
	EndDo;
	
	Return QueryTable;
	
EndFunction

Procedure WritePublicIdentifierIfNeeded(DataForEIBWrite, ReceivedDataRef, ExchangeNode, ConversionRule)
	
	IdentificationVariant = TrimAll(ConversionRule.IdentificationVariant);
	If Not IdentificationVariant = "FirstByUniqueIdidentifierThenBySearchFields" Then
		Return;
	EndIf;
	
	If DataForEIBWrite.IsNew() Then
		Return;
	EndIf;
	
	If ReceivedDataRef = DataForEIBWrite.Ref Then
		Return;
	EndIf;
		
	RecordStructure = New Structure;
	RecordStructure.Insert("ID", ReceivedDataRef.UUID());
	RecordStructure.Insert("Ref", DataForEIBWrite.Ref);
	RecordStructure.Insert("InfobaseNode", ExchangeNode);
	
	If InformationRegisters.SynchronizedObjectPublicIDs.NoteHasInRegister(RecordStructure) Then
		Return;
	EndIf;
	
	InformationRegisters.SynchronizedObjectPublicIDs.AddRecord(RecordStructure, True);	
	
EndProcedure

Function XMLBasicSchema()
	
	Return "http://www.1c.ru/SSL/Exchange/Message";
	
EndFunction

Function ExchangePlanManager(Val InfobaseNode)
	
	Return ExchangePlans[InfobaseNode.Metadata().Name];
	
EndFunction

#EndRegion

#EndRegion
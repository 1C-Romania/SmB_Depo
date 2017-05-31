// Jack 29.05.2017
//////////////////////////////////////////////////////////////////////////////////
//// PROCEDURES - EVENTS PROCESSING OF THE OBJECT

//Procedure Filling(FillingData, StandardProcessing)
//	
//	If ThisObject.Ref.IsEmpty() Then	
//		
//		TmpParent = Undefined;
//		If FillingData <> Undefined AND TypeOf(FillingData) = Type("Structure") Then
//			FillingData.Property("Parent",TmpParent);
//		EndIf;	
//		
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("BaseUnitOfMeasure",     ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("PurchaseUnitOfMeasure", ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("SalesUnitOfMeasure",    ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("AccountingGroup",       ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("SalesPriceGroup",       ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("MainBarCodeType",       ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("OriginCountry",         ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("CustomDuty",            ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("SupplementaryUnitOfMeasure", ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("BaseSupplier", ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("Vendor", ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("OriginCountry", ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("IntrastatCNCode", ThisObject,TmpParent);
//		ObjectsExtensionsAtServer.SetCatalogAttributeFromParent("IntrastatCNDescription", ThisObject,TmpParent);
//		
//		ObjectsExtensionsAtServer.SetCatalogShortFirstCode(ThisObject);
//		
//	EndIf;	

//EndProcedure

//Procedure FillCheckProcessing(Cancel, CheckedAttributes)
//	
//	If IsFolder Then
//		CheckedAttributes.Clear();
//		CheckedAttributes.Add("Description");
//	EndIf;	
//	
//EndProcedure

//Procedure OnCopy(CopiedObject)
//	
//	If CopiedObject.MainItem = CopiedObject.Ref Then
//		MainItem = Catalogs.Items.EmptyRef();
//	EndIf;	
//	
//EndProcedure

//Procedure BeforeWrite(Cancel)
//	
//	If Not DataExchange.Load Then

//		ObjectsExtensionsAtServer.TableUniquenessRowValidation(ThisObject,"UnitsOfMeasure","UnitOfMeasure",Cancel);
//		
//		ObjectsExtensionsAtServer.DoCommonCheck(ThisObject,Cancel);
//		
//		If StrLen(LongDescription) > 1000 Then
//			CommonAtClientAtServer.NotifyUser(Nstr("en=""Length of long description cann't exceed 1000 chars. You input:"";pl='Liczba znaków długiego opisu nie może przekraczać 1000 znaków. Wprowadziłeś:';ru='Количество символов полного наименования не должно превышать 1000 символов. Вами введено:'") + " " + StrLen(LongDescription), ThisObject, "LongDescription",,Cancel);
//		EndIf;
//		
//		LongDescriptionEn = LanguagesModulesServer.GetDescription(ThisObject, Catalogs.Languages.English);
//		If StrLen(LongDescriptionEn) > 1000 Then
//			CommonAtClientAtServer.NotifyUser(Nstr("en=""Length of long description (eng.) cann't exceed 1000 chars. You input:"";pl='Liczba znaków długiego opisu (ang.) nie może przekraczać 1000 znaków. Wprowadziłeś:';ru='Количество символов полного наименования (англ.) не должно превышать 1000 символов. Вами введено:'") + " " + StrLen(LongDescriptionEn), ThisObject, "LongDescription",,Cancel);
//		EndIf;
//		
//		LongDescriptionRu = LanguagesModulesServer.GetDescription(ThisObject, Catalogs.Languages.Russian);
//		If StrLen(LongDescriptionRu) > 1000 Then
//			CommonAtClientAtServer.NotifyUser(Nstr("en=""Length of long description (rus.) cann't exceed 1000 chars. You input:"";pl='Liczba znaków długiego opisu (ros.) nie może przekraczać 1000 znaków. Wprowadziłeś:';ru='Количество символов полного наименования (рус.) не должно превышать 1000 символов. Вами введено:'") + " " + StrLen(LongDescriptionRu), ThisObject, "LongDescription",,Cancel);
//		EndIf;
//		
//		If Cancel Then
//			Return;
//		EndIf;
//		
//		If Not IsFolder Then
//				
//			If Cancel Then
//				Return;
//			EndIf;
//			
//			If PurchaseUnitOfMeasure <> BaseUnitOfMeasure Then
//				
//				FoundRow = TablesProcessingAtClientAtServer.FindTabularPartRow(UnitsOfMeasure, New Structure("UnitOfMeasure",PurchaseUnitOfMeasure));
//				If FoundRow = Undefined Then
//					CommonAtClientAtServer.NotifyUser(CommonAtClientAtServer.ParametrizeString(Nstr("en='There is no quantity defined for %P1 UoM. This UoM was used as purchase UoM!';pl='Nie został zdefiniowany współczynnik dla jednostki miary %P1, która została użyta jako j.m. zakupu!';ru='Не указан коэффициент пересчета для единицы измерения %P1, которая была выбрана в качестве ед. покупки!'"),New Structure("P1",PurchaseUnitOfMeasure)), ThisObject, "PurchaseUnitOfMeasure",,Cancel);
//				EndIf;	
//				
//			EndIf;	
//			
//			If SalesUnitOfMeasure <> BaseUnitOfMeasure Then
//				
//				FoundRow = TablesProcessingAtClientAtServer.FindTabularPartRow(UnitsOfMeasure, New Structure("UnitOfMeasure",SalesUnitOfMeasure));
//				If FoundRow = Undefined Then
//					CommonAtClientAtServer.NotifyUser(CommonAtClientAtServer.ParametrizeString(Nstr("en='There is no quantity defined for %P1 UoM. This UoM was used as sales UoM!';pl='Nie został zdefiniowany współczynnik dla jednostki miary %P1, która została użyta jako j.m. sprzedaży!';ru='Не указан коэффициент пересчета для единицы измерения %P1, которая была выбрана в качестве ед. продажи!'"),New Structure("P1",SalesUnitOfMeasure)), ThisObject, "SalesUnitOfMeasure",,Cancel);
//				EndIf;
//				
//			EndIf;
//			
//			If ValueIsFilled(SupplementaryUnitOfMeasure) AND SupplementaryUnitOfMeasure <> BaseUnitOfMeasure Then
//				
//				FoundRow = TablesProcessingAtClientAtServer.FindTabularPartRow(UnitsOfMeasure, New Structure("UnitOfMeasure",SupplementaryUnitOfMeasure));
//				If FoundRow = Undefined Then
//					CommonAtClientAtServer.NotifyUser(CommonAtClientAtServer.ParametrizeString(Nstr("en='There is no quantity defined for %P1 UoM. This UoM was used as supplymentary UoM!';pl='Nie został zdefiniowany współczynnik dla jednostki miary %P1, która została użyta jako uzupełniająca j.m.!';ru='Не указан коэффициент пересчета для единицы измерения %P1, которая была выбрана в качестве дополнительной ед. изм.!'"),New Structure("P1",SupplementaryUnitOfMeasure)), ThisObject, "SupplementaryUnitOfMeasure",,Cancel);
//				EndIf;
//				
//			EndIf;
//			
//			FoundRow = TablesProcessingAtClientAtServer.FindTabularPartRow(UnitsOfMeasure, New Structure("UnitOfMeasure",BaseUnitOfMeasure));
//			If FoundRow = Undefined Then
//				CommonAtClientAtServer.NotifyUser(CommonAtClientAtServer.ParametrizeString(Nstr("en='There is no quantity defined for %P1 UoM. This UoM was used as base UoM!';pl='Nie został zdefiniowany współczynnik dla jednostki miary %P1, która została użyta jako bazowa j.m.!';ru='Не указан коэффициент пересчета для единицы измерения %P1, которая была выбрана в качестве базовой ед. изм.!'"),New Structure("P1",BaseUnitOfMeasure)), ThisObject, "BaseUnitOfMeasure",,Cancel);
//			Else
//				If FoundRow.Quantity <> 1 Then
//					CommonAtClientAtServer.NotifyUser(CommonAtClientAtServer.ParametrizeString(Nstr("en='Only 1 quantity may be defined for base UoM! %P1 selected as base UoM!';pl='Współczynnik musi dorównywać 1 dla bazowej j.m.!%P1 została wybrana jako bazowa j.m.!';ru='Коэффициент пересчета для базовой единицы измерения равен 1! P1 выбрана в качестве базовой ед. изм.!'"),New Structure("P1",BaseUnitOfMeasure)), ThisObject, "BaseUnitOfMeasure",,Cancel);
//				EndIf;
//			EndIf;
//			
//			UnitsOfMeasureArray = New Array;
//			RefUnitsOfMeasureArray = New Array;
//			
//			For Each RefUnitsOfMeasureRow In Ref.UnitsOfMeasure Do
//				
//				AddUnitOfMeasure = True;
//				For Each UnitsOfMeasureRow In UnitsOfMeasure Do
//					If RefUnitsOfMeasureRow.UnitOfMeasure = UnitsOfMeasureRow.UnitOfMeasure
//						And RefUnitsOfMeasureRow.Quantity = UnitsOfMeasureRow.Quantity Then
//						AddUnitOfMeasure = False;
//						Break;
//					EndIf;
//				EndDo;
//				
//				If AddUnitOfMeasure Then
//					UnitsOfMeasureArray.Add(RefUnitsOfMeasureRow.UnitOfMeasure);
//				EndIf;
//				RefUnitsOfMeasureArray.Add(RefUnitsOfMeasureRow.UnitOfMeasure);
//				
//			EndDo;
//			
//			For Each UnitsOfMeasureRow In UnitsOfMeasure Do
//				// It is possible to add only UoM with quantity 1.
//				// If other quantity we should check this UoM in documents.
//				If RefUnitsOfMeasureArray.Find(UnitsOfMeasureRow.UnitOfMeasure) = Undefined
//					And UnitsOfMeasureRow.Quantity <> 1 Then
//					UnitsOfMeasureArray.Add(UnitsOfMeasureRow.UnitOfMeasure);
//				EndIf;
//			EndDo;
//			
//			Privileged.IsCatalogInPostedDocuments_ForUoM(UnitsOfMeasureArray, Ref, Cancel);
//			
//			If Cancel Then
//				Return;
//			EndIf;
//			
//		EndIf;
//		
//	EndIf;
//	
//	If Not IsFolder Then
//		
//		If IsNew() AND GetNewObjectRef().IsEmpty() Then
//			CurrentRef = Catalogs.Items.GetRef();
//			SetNewObjectRef(CurrentRef);
//		Else
//			CurrentRef = Ref;
//		EndIf;
//		
//		If IsNew() Then
//			Date = GetServerDate();
//			Author = SessionParameters.CurrentUser;	
//		EndIf;	
//		
//		If MainItem.IsEmpty() Then
//			MainItem = CurrentRef;
//		EndIf;
//		
//	EndIf;
//	
//	If Not IsFolder And AccountingGroup.ItemType <> Enums.ItemTypes.Services Then
//		CostArticle                = Undefined;
//		VATOffsettingInPaymentDate = False;
//	EndIf;
//	
//EndProcedure


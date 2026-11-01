import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../config/field_api.dart';

/// Authenticated tenant brand. Falls back gracefully when offline.
class CompanyIdentityBanner extends StatefulWidget {
  const CompanyIdentityBanner({super.key, required this.accessToken, required this.fallbackName});
  final String accessToken;
  final String fallbackName;
  @override
  State<CompanyIdentityBanner> createState() => _CompanyIdentityBannerState();
}

class _CompanyIdentityBannerState extends State<CompanyIdentityBanner> {
  String? _name;
  Uint8List? _logo;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(CompanyIdentityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(oldWidget.accessToken != widget.accessToken) _load();
  }
  Future<void> _load() async {
    try {
      final data=await FieldApi(accessToken: widget.accessToken).getJson('/api/salesApp/company/profile');
      final raw=data['profile'];
      if (raw is! Map) return;
      final name=(raw['displayName']??'').toString().trim();
      final logo=raw['logoDataUrl']?.toString()??'';
      Uint8List? bytes;
      try { if(logo.startsWith('data:image/') && logo.contains(',')) bytes=base64Decode(logo.split(',').last); } catch (_) {}
      if(mounted) setState(() { _name=name.isNotEmpty?name:null; _logo=bytes; });
    }catch (_) { /* Offline fallback keeps the app usable. */ }
  }
  @override
  Widget build(BuildContext context) {
    final name=_name??widget.fallbackName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal:14,vertical:12),
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant)),
      child:Row(children:[
        ClipRRect(borderRadius:BorderRadius.circular(12),child:Container(width:42,height:42,color:Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment:Alignment.center,child:_logo!=null?Image.memory(_logo!,width:42,height:42,fit:BoxFit.contain)
          :Text(name.isNotEmpty?name.substring(0,1).toUpperCase():'B',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:19)))),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('YOU ARE WORKING WITH',style:Theme.of(context).textTheme.labelSmall),
          Text(name,maxLines:2,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.titleMedium),
        ])),
        IconButton(onPressed:_load,icon:const Icon(Icons.refresh_rounded),tooltip:'Refresh company identity'),
      ]),
    );
  }
}

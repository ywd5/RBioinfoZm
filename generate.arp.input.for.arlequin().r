#last edited at 20200105

library(magrittr)
library(ape)
library(seqinr)
library(stringr)

generate.arp.input.for.arlequin=function(
  distribution.tsv,sequence.fasta,
  title="an analysis of a DNA segment from genus species",
  haplotype_or_genotype=c("haplotype","genotype")[1],
  sequence_list_name="haplotype/genotype list of a DNA segment from genus species",
  structure_name="genus sepcies"
){
  #>>>internal functions begin>>>
  f_any_empty=function(va){
    #for internal usage only
    result=FALSE
    if(is.null(va)){result=TRUE;}
    if(!result){va=str_squish(as.character(unlist(va)));}
    if(!result)if(length(va)==0){result=TRUE;}
    if(!result)if(anyNA(va)){result=TRUE;}
    if(!result)if(any(va=="")){result=TRUE;}
    return(result)#rm(va,result)
  }
  #<<<internal functions end<<<
  #>>>control the input of title, haplotype_or_genotype, sequence_list_name, structure_name begin>>>
  metainfo=list(title=title,hog=haplotype_or_genotype,sln=sequence_list_name,sn=structure_name)
  rm(title,haplotype_or_genotype,sequence_list_name,structure_name)
  tulip=c("title","haplotype_or_genotype","sequence_list_name","structure_name")
  for(i in 1:length(metainfo)){
    if(!is.vector(metainfo[[i]])|is.list(metainfo[[i]])){stop(tulip[i]," must be a string")}
    if(length(metainfo[[i]])!=1){stop("length(",tulip[i],") must be 1")}
    metainfo[[i]]=as.character(metainfo[[i]]) %>% str_squish()
    if(is.na(metainfo[[i]])){stop(tulip[i]," can't be NA")}
    if(metainfo[[i]]==""){stop(tulip[i]," can't be an empty string")}
  }
  if(! metainfo$hog%in%c("haplotype","genotype")){stop("haplotype_or_genotype must be one of haplotype or genotype.")}
  rm(tulip)
  #<<<control the input of title, haplotype_or_genotype, sequence_list_name, structure_name end<<<
  #>>>control the input of distribution.tsv and sequence.fasta begin>>>
  if(!is.vector(distribution.tsv)|is.list(distribution.tsv)|length(distribution.tsv)!=1){
    stop("distribution.tsv must be a string.")
  }
  if(!is.vector(sequence.fasta)|is.list(sequence.fasta)|length(sequence.fasta)!=1){
    stop("sequence.fasta must be a string.")
  }
  if(!file.exists(distribution.tsv)){stop("files specified by distribution.tsv doesn't exist.")}
  if(!file.exists(sequence.fasta)){stop("files specified by sequence.fasta doesn't exist.")}
  #
  ma=read.table(file=distribution.tsv,fileEncoding="UTF-8-BOM",sep="\t",
                              header=TRUE,stringsAsFactors=FALSE,row.names=1) %>% as.matrix()
  if(f_any_empty(va=ma)){stop("items in distribution.tsv can't be NA or \"\"")}
  if(f_any_empty(va=rownames(ma))|f_any_empty(va=colnames(ma))){
    stop("rownames and colnames of the matrix in distribution.tsv must be specified.")
  };rownames(ma)=str_squish(rownames(ma));colnames(ma)=str_squish(colnames(ma));
  #
  seq=ape::read.FASTA(file=sequence.fasta,type="DNA") %>% as.matrix()
  if(nrow(seq)==0|ncol(seq)==0){stop("sequences in sequence.fasta can't be empty")}
  if(f_any_empty(va=rownames(seq))){stop("sequences in sequence.fasta must have valid names")}
  rownames(seq)=str_squish(rownames(seq))
  #
  if(ncol(ma)!=nrow(seq)){stop("column number in distribution.tsv must equal number of sequences in sequence.fasta");}
  if(any(colnames(ma)!=rownames(seq))){stop("haplotype/genotype names in distribution.tsv don't match with those in sequence.fasta");}
  rm(distribution.tsv,sequence.fasta)
  #>>>export result begin>>>
  output_file=strftime(Sys.time(),format="input for arlequin, %Y%m%d_%H%M%S.arp")
  if(file.exists(output_file)){stop("can't create the file: \"",output_file,"\".\t it already exists.")}
  tulip=file(description=output_file,open="wt",blocking=FALSE)
  cat("[Profile]\n",
      "  Title=\"",metainfo$title,"\"\n",
      "  NbSamples=",nrow(ma),"\n",
      "  DataType=DNA\n",
      "  GenotypicData=0\n",
      "  LocusSeparator=WHITESPACE\n",
      "  MissingData='?'\n",
      "  Frequency=ABS\n",
      "\n",
      "[Data]\n",
      "\n",
      "  [[",str_to_title(metainfo$hog),"Definition]]\n",
      "    ",if(metainfo$hog=="haplotype"){"Hapl"}else{"Gen"},"ListName=\"",metainfo$sln,"\"\n",
      "    ",if(metainfo$hog=="haplotype"){"Hapl"}else{"Gen"},"List={\n",
      file=tulip,append=FALSE,sep=""
      )
  #
  ans=rownames(seq) %>% {str_pad(string=.,width=max(nchar(.))+2,side="right")}
  for(i in 1:nrow(seq)){
    cat(strrep(" ",times=6),ans[i],seqinr::c2s(toupper(as.character(seq[i,]))),"\n",file=tulip,append=TRUE,sep="")
  }
  rm(ans)
  #
  cat("    }\n",
      "  \n",
      "  [[Samples]]\n",
      file=tulip,append=TRUE,sep=""
      )
  #
  for(i in 1:nrow(ma)){
    ans=ma[i,] %>% {cbind(names(.),unname(.))} %>% {.[.[,2]!="0",]}
    if(is.vector(ans)){if(length(ans)!=2){stop("internal bug");};ans=cbind(ans[1],ans[2]);}
    ans[,1] %<>% {str_pad(string=.,width=max(nchar(.))+2,side="right")}
    ans=paste0(strrep(" ",times=6),ans[,1],ans[,2],"\n")
    cat("    SampleName=\"",rownames(ma)[i],"\"\n",
        "    SampleSize=",sum(ma[i,]),"\n",
        "    SampleData={\n",
        ans,
        "    }\n",
        file=tulip,append=TRUE,sep=""
        )
    rm(ans)
  }
  #
  cat("\n",
      "  [[Structure]]\n",
      "    StructureName=\"",metainfo$sn,"\"\n",
      "    NbGroups=1\n",
      "    Group={\n",
      paste0(strrep(" ",times=6),"\"",rownames(ma),"\"\n"),
      "    }\n",
      file=tulip,append=TRUE,sep=""
      )
  close(tulip);rm(tulip)
  message("\nresult is written in: \"",output_file,"\".\n")
  #<<<export result end<<<
  rm(i,f_any_empty,metainfo,ma,seq)
  invisible(output_file)#rm(output_file)
}

if(FALSE){
  #here are the test codes
  ans=expand.grid(c("its","rbcl","trnsg"),c("haplotype","genotype"),stringsAsFactors=FALSE) %>% {.[order(.[,1]),]}
  for(i in 1:nrow(ans)){
    distribution.tsv=paste0("~/../OneDrive/Sep13_atrata/analysis/atrata-",ans[i,1],
                            ", ",ans[i,2],", distribution in populations.tsv")
    sequence.fasta=paste0("~/../OneDrive/Sep13_atrata/analysis/atrata-",ans[i,1],
                     ", ",ans[i,2],", sequence.fasta")
    tempo=generate.arp.input.for.arlequin(distribution.tsv,sequence.fasta,
                                          title=paste0("an analysis of ",ans[i,1]," from Micranthes atrata"),
                                          haplotype_or_genotype=ans[i,2],
                                          sequence_list_name=paste0(ans[i,2]," list of ",ans[i,1]," from Micranthes atrata"),
                                          structure_name="Micranthes atrata"
                                          ) %>% c(.,"")
    tempo[2]=paste0("atrata-",ans[i,1],", ",ans[i,2],", ",gsub(", [[:digit:]]{8}_[[:digit:]]{6}","",tempo[1]))
    file.rename(from=tempo[1],to=tempo[2]) %>% {if(!.){stop("file renaming error")}}
    rm(tempo)
  }
  rm(ans,i,distribution.tsv,sequence.fasta,generate.arp.input.for.arlequin)
}

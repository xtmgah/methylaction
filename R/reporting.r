# Functions for summary and plotting after analysis has been run

# ====================================================================
# Exported Functions

# --------------------------------------------------------------------
#' Summary stats for a run of methylaction()
#'
#' Will return information about number of windows/regions that pass cutoffs at each stage of the analysis. Useful for parameter tuning.
#' @param ma Output object from methylaction()
#' @return A data.frame with the summary statistics
#' @export
maSummary <- function(ma)
{
	per <- function(x,digits=2){round(x*100,digits)}

	# Initial Filtering
	df <- data.frame(stat="Window Size",count=ma$args$winsize,percent="",stringsAsFactors=F)
	wins <- length(ma$data$windows$zero) + length(ma$data$windows$filtered) + length(ma$data$windows$signal.norm)
	df <- rbind(df,c("Total Windows",wins,""))
	zero <- length(ma$data$windows$zero)
	filt <- length(ma$data$windows$filtered)
	signal <- length(ma$data$windows$signal.norm)
	df <- rbind(df,c("All Zero Windows (filtered)",zero,per(zero/wins)))
	df <- rbind(df,c("All Below FDR Windows (filtered)",filt,per(filt/wins)))
	df <- rbind(df,c("Signal Windows (move on to stage one)",signal,per(signal/wins)))

	# Stage One Testing
	owins <- length(ma$data$test.one$patterns)
	osig <- length(ma$data$test.one$patterns[!(ma$data$test.one$patterns$patt %in% c("000or111","ambig"))])
	ons <- length(ma$data$test.one$patterns[(ma$data$test.one$patterns$patt %in% c("000or111"))])
	oamb <- length(ma$data$test.one$patterns[(ma$data$test.one$patterns$patt %in% c("ambig"))])
	df <- rbind(df,c("Windows Tested in Stage One",owins,""))
	df <- rbind(df,c("Sig Pattern in Stage One",osig,per(osig/owins)))
	df <- rbind(df,c("Non-Sig Pattern in Stage One",ons,per(ons/owins)))
	df <- rbind(df,c("Ambig Pattern in Stage One",oamb,per(oamb/owins)))
	df <- rbind(df,c("Regions Formed By Joining Adjacent Patterns",length(ma$data$test.one$regions),""))

	# Stage Two Testing
	treg <- length(ma$data$test.two$sig) + length(ma$data$test.two$ns)
	df <- rbind(df,c("Regions Tested in Stage Two",treg,""))
	tsig <- length(ma$data$test.two$sig)
	df <- rbind(df,c("Regions That Pass ANODEV",tsig,per(tsig/treg)))

	tpsig <- length(ma$data$test.two$dmr[!(ma$data$test.two$dmr$pattern %in% c("000or111","ambig"))])
	tpns <- length(ma$data$test.two$dmr[(ma$data$test.two$dmr$pattern %in% c("000or111"))])
	tpamb <- length(ma$data$test.two$dmr[(ma$data$test.two$dmr$pattern %in% c("ambig"))])

	df <- rbind(df,c("ANODEV Sig with Sig Pattern",tpsig,per(tpsig/tsig)))
	df <- rbind(df,c("ANODEV Sig with Non-sig Pattern",tpns,per(tpns/tsig)))
	df <- rbind(df,c("ANODEV Sig with Ambig Pattern",tpamb,per(tpamb/tsig)))

	# DMRs
	df <- rbind(df,c("Total DMRs",tpsig,""))
	return(df)
}
# --------------------------------------------------------------------

# --------------------------------------------------------------------
#' Karyogram of the differentially methylated regions (DMRs) found by a run of methylaction()
#'
#' Will plot a karyogram of the DMRs. A black line above shows regions of coverage by the sequencing experiment.
#' @param ma Output object from methylaction()
#' @param reads Preprocessed reads/fragments data from getReads()
#' @param frequentonly Only plot for DMRs where "frequent" is TRUE
#' @param patt Character vector of patterns to restrict plot to
#' @param colors Character vector of custom colors (as hex codes) for each pattern in patt
#' @param file Where to save the image (PDF format), if NULL, will print to current graphics device
#' @return Saves plot to disk or outputs to graphics device
#' @export
maKaryogram <- function(ma,reads,frequentonly=TRUE,patt=NULL,colors=NULL,file=NULL)
{
	# Get DMRs
	dmr.gr <- ma$dmr
	
	# Filter DMRs
	if(frequentonly==TRUE)
	{
		dmr.gr <- dmr.gr[dmr.gr$frequent==TRUE]
	}
	if(!is.null(patt))
	{
		dmr.gr <- dmr.gr[dmr.gr$pattern %in% patt]
	} else {
		patt <- unique(dmr.gr$pattern)
	}

	# Want line on top showing everywhere we have reads (signal bins)
	line.gr <- reduce(ma$data$windows$signal.norm, min.gapwidth=100000)
	#line.gr <- reduce(line.gr,min.gapwidth=100000)

	# Regions to plot, auto-use "pattern" as grouping
	#data(hg19Ideogram, package = "biovizBase")
	#ci <- getUCSCTable("chromInfo",genome=genome)
	#seqlengths(dmr.gr) <- ci[match(names(seqlengths(dmr.gr)),ci$chrom),]$size
	#seqlengths(dmr.gr) <- seqlengths(hg19Ideogram)[names(seqlengths(dmr.gr))]
	#dmr.gr <- keepSeqlevels(dmr.gr, paste0("chr", c(1:22, "X")))
	#seqlengths(line.gr) <- ci[match(names(seqlengths(line.gr)),ci$chrom),]$size
	#seqlengths(line.gr) <- seqlengths(hg19Ideogram)[names(seqlengths(line.gr))]
	#line.gr <- keepSeqlevels(line.gr, paste0("chr", c(1:22, "X")))

	stopifnot(seqlevels(dmr.gr)==seqlevels(reads[[1]]))
	stopifnot(seqlevels(line.gr)==seqlevels(reads[[1]]))
	seqlengths(dmr.gr) <- seqlengths(reads[[1]])
	seqlengths(line.gr) <- seqlengths(reads[[1]])

	# Get genome structure
	#data(hg19IdeogramCyto, package = "biovizBase")
	#hg19 <- keepSeqlevels(hg19IdeogramCyto, paste0("chr", c(1:22, "X", "Y")))

	# Plot
	#dir.create("output/karyogram",showWarnings=FALSE)
	
	#specific to high
	##e31a1c hyper 001
	##fb9a99 hypo 110

	#specific to low
	##377eb8 hyper 010
	##a6cee3 hypo 101

	#specific to cancer
	##ff7f00 hyper 011
	##fdbf6f hypo 100

	dmr.gr$pattern <- factor(dmr.gr$pattern, levels=patt)
	morecolors <- function(n, rand=FALSE)
	{
		# Brewer's qualitative palette "Set1" only has 9 values
		# Extrapolate from these to create palettes of any size
		pal <- colorRampPalette(RColorBrewer::brewer.pal(9,"Set1"))(n)
		if(rand==TRUE){pal <- sample(pal)}
		pal
	}
	#colors <- c("#7570b3","#d95f02")
	if(is.null(colors))
	{
		colors <- morecolors(length(patt))
	}
	#dmr.gr$pattern <- factor(dmr.gr$pattern, levels=c("001","110","010","101","011","100"))
	#colors <- c("#e31a1c","#fb9a99","#377eb8","#a6cee3","#4d4d4d","#878787")

	if(!is.null(file))
	{
		pdf(file=file,width=5,height=5)
	}
	print(ggbio::autoplot(seqinfo(dmr.gr)) + ggbio::layout_karyogram(dmr.gr, geom="rect",aes(color=pattern,fill=pattern)) + ggbio::layout_karyogram(line.gr, geom = "rect", ylim = c(14, 15), color="black",fill="black") + scale_color_manual(values=colors) + scale_fill_manual(values=colors) + theme(panel.background = element_rect(fill = 'white'),strip.background=element_rect(fill="white")))
	if(!is.null(file))
	{
		dev.off()
	}
}


# --------------------------------------------------------------------

# --------------------------------------------------------------------
#' Heatmap of the differentially methylated regions (DMRs) found by a run of methylaction()
#'
#' Will plot a heatmap of the DMRs based on the normalized read counts. The square root of the mean per-window normalized read count is used so DMRs of different lengths are comparable.
#' @param ma Output object from methylaction()
#' @param frequentonly Only plot for DMRs where "frequent" is TRUE
#' @param bias Bias setting for the color scale
#' @param sep Add spaces between pattern groups on the rows and sample groups on the columns
#' @param sort Sort by rowSums within each pattern group 
#' @param sat Value (on square root scale) at which scale saturates (read counts at this level or above will all be the same hue) 
#' @param file Where to save the image (PNG format), if NULL, will print to current graphics device
#' @return Saves plot to disk or outputs to graphics device
#' @export
maHeatmap <- function(ma,frequentonly=TRUE,bias=2,sep=TRUE,sort=F,sat=7,file=NULL)
{
	sites <- ma$dmr

	# Restrict to frequent only if requested
	if(frequentonly==TRUE)
	{
		sites <- sites[sites$frequent==TRUE]
	}

	# Extract counts matrix
	mat <- as.matrix(values(sites))
	samp <- ma$args$samp
	mat <- mat[,colnames(mat) %in% samp$sample]
	stopifnot(colnames(mat)==samp$sample)

	# Set scale inflection point based on POI cutoffs
	inflect <- sqrt(mean(ma$data$fdr.filter$cuts))

	# sqrt transform the matrix and make the means per-window
	mat <- sqrt(mat)

	# saturate high read counts using "max"
	if(sum(mat>sat)>0)
	{
		mat[mat>sat] <- sat
	}

	# Get upper bound for saturation
	upper <- sat

	# Generate colors
	ncolors <- 100
	per <- round((inflect/upper)*100,0)/100
	pal1size <- round(per*ncolors)
	pal1 <- colorRampPalette(rev(c("#313695","#4575b4","#fee090")),bias=bias)(pal1size)
	pal2 <- colorRampPalette(c("#fee090","#f46d43","#d73027","#a50026"),bias=bias)(ncolors-pal1size)
	cols <- c(rev(pal1),pal2)

	# If the max is less than sat, we need to zoom the scale in
	if(max(mat)<sat)
	{
		cols <- cols[1:round(max(mat)/upper*100)]
	}

	# Do sorting
	if(sort==TRUE)
	{
		mat <- mat[order(sites$pattern,rowSums(mat),decreasing=TRUE),]
		sites <- sites[order(sites$pattern,decreasing=TRUE)]
	}
	
	# Do plotting
	#pdf(file=pdf,width=8,height=10.5)
	if(!is.null(file))
	{
		png(filename=file,width=2550,height=3300,res=300)
	}
	sc <- c(benign="#4daf4a",low="#377eb8",high="#e41a1c")
	samp <- ma$args$samp
	sc <- unique(samp$color)
	names(sc) <- unique(samp$group)
	csc <- sc[match(samp$group,names(sc))]

	cs <- numeric(0)
	last <- ""
	for(i in 1:nrow(samp))
	{
		if(samp[i,]$group != last)
		{
			cs <- c(cs,i)
		}
		last <- samp[i,]$group
	}

	cs <- (cs-1)[-1] 

	rs <- match(unique(sites$pattern),sites$pattern)
	rs <- (rs-1)[-1] 
	if(sep==TRUE)
	{
		suppressWarnings(gplots::heatmap.2(mat,Colv=F,Rowv=F,trace="none",labRow=F,col=cols,ColSideColors=csc,colsep=cs, sepwidth=c(0.15,5),rowsep=rs))
	} else
	{
		suppressWarnings(gplots::heatmap.2(mat,Colv=F,Rowv=F,trace="none",labRow=F,col=cols,ColSideColors=csc))
	}
	if(!is.null(file))
	{
		dev.off()
		message("Plot saved to ",file)
	}
}
# --------------------------------------------------------------------

# --------------------------------------------------------------------
#' Write BED and BIGWIG files for normalized, filter-passed window count values
#'
#' Creates a BED file suitable for uploading as a custom track to the UCSC genome browser.
#' @param ma Output list from a run of methylaction()
#' @param reads Preprocessed reads/fragments data from getReads()
#' @param path Folder to save the files in, will create if does not exist
#' @param bigwig If TRUE, convert the BED to BIGWIG files, requires wigToBigWig in $PATH (obtain from the Jim Kent source tree)
#' @param ncore Number of parallel processes to use
#' @return Writes BED file to disk and optionally converts to a bigWig file.
#' @export
maTracks <- function(ma, reads, path=".", bigwig=FALSE, ncore=1)
{
	#if((bigwig==TRUE)&((is.null(chrs))|(is.null(bsgenome)))){stop("Must give chrs and bsgenome if bigwig=TRUE")}
	#if(is.null(counts)){stop("Must give list of data as counts argument")}
	dir.create(path,showWarnings=F)
	# Make one GRanges for all bin coordinates
	#bins.gr <- suppressWarnings(do.call(c,lapply(names(counts$bins), function(x) GRanges(x,counts$bins[[x]]))))
	#chrlens <- seqlengths(bsgenome)[chrs]
	chrs <- seqlevels(reads[[1]])
	chrlens <- seqlengths(reads[[1]])

	signal <- ma$data$windows$signal.norm

	writeBed <- function(x)
	{
		message(paste(x,": Creating BedGraph",sep=""))
		filename <- file.path(path,paste(x,".bed",sep=""))
		values <- values(signal)[,x]
		bed <- data.frame(chr=seqnames(signal), start=as.integer(start(signal)-1), end=as.integer(end(signal)), value=values)
		bed <- bed[bed$value>0,]
		#trackheader <- paste("track","type=wiggle_0",paste("name=",x,sep=""),sep=" ")
		#write(trackheader,file=filename)
		write.table(bed, file=filename, append=FALSE, quote=FALSE, row.names=FALSE, col.names=FALSE, sep="\t")

		if(bigwig==TRUE)
		{
			message(paste(x,": Converting to BigWig",sep=""))
			cs <- tempfile(x)
			write.table(data.frame(chrs,chrlens),col.names=F,row.names=F,file=cs, quote=F)
			cmd <- paste("wigToBigWig",filename,cs,file.path(path,paste(x,".bw",sep="")),sep=" ")
			message(cmd)
			system(cmd)
			file.remove(cs)
		}
	}
	# want to print all series of data in the file expect the bin metadata
	mclapply(ma$args$samp$sample, writeBed, mc.cores=ncore)
	NULL
}
# --------------------------------------------------------------------

# --------------------------------------------------------------------
#' Write BED file of DMR regions
#'
#' Creates a BED file suitable for uploading as a custom track to the UCSC genome browser.
#' @param ma Output list from a run of methylaction()
#' @param file Name of BED file to create
#' @return Writes BED file to disk.
#' @export
maBed <- function(ma, file)
{
	call.gr <- ma$dmr
	values(call.gr) <- NULL
	call.gr$call <- as.character(ma$dmr$pattern)
	call.gr$call[ma$dmr$frequent==FALSE] <- paste0("other_",as.character(call.gr$call[ma$dmr$frequent==FALSE]))

	# Make BED
	bed <- data.frame(chr=seqnames(call.gr),start=as.integer(start(call.gr)-1),end=as.integer(end(call.gr)),name=call.gr$call, score=0, strand="+", thickStart=as.integer(start(call.gr)-1),thickEnd=as.integer(end(call.gr)))

	patts <- unique(bed$name)
	pal <- colorRampPalette(RColorBrewer::brewer.pal(8,"Set2"))(length(patts))
	#pal <- sample(pal)

	mycols <- data.frame(name=patts,color=pal)
	mycols$itemRgb <- apply(col2rgb(mycols$color),2,function(x) paste(x,collapse=","))
	bed$itemRgb <- mycols[match(bed$name,mycols$name),]$itemRgb

	# Write BED
	if(file.exists(file)){file.remove(file)}
	header <- "track name=\"methylaction\" itemRgb=\"On\" visibility=\"pack\""
	cat(header, '\n',file=file)
	write.table(bed,file=file, col.names=F, row.names=F, sep=" ", quote=F,append=T)

	NULL
}
# --------------------------------------------------------------------
# ====================================================================

# ====================================================================
# Internal Functions

# ====================================================================

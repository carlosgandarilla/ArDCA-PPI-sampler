#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
"""
	'dij_hist_generative'
Plots histograms of Hamming distance matrices for sampled MSAs asociated to 
protein families A, B and A-B:

* 'inputsample': input H5DF file with data, 
* 'figoutput': output pdf file with figure;

The keyword arguments for the histogram with their default value:

* 'binsA'=80: bins for histogram of dij from familiy A,
* 'binsB'=80: bins for histogram of dij from familiy B,
* 'binsC'=120: bins for histogram of dij from A-B co-MSA,
* 'y_max'=10.0: is the the upper bound for y-axis.

Example of use:

inputsample = "./data/HK-RR_ArDCA_Natural_1to1_M=10000.h5"
figoutput = "./HK-RR_ArDCA_Natural_1to1"
dij_hist_generative(inputsample, figoutput, binsA=80, binsB=80, binsC=120, y_max = 20.0)
"""

function dij_hist_generative(inputsample::String, 
                figoutput::String;
                binsA=80::Int,
                binsB=80::Int,
                binsC=80::Int,
                y_max=10.0::Float64)
                
    #inputsample input H5DF file with data, 
    #figoutput output pdf file with figure;
    #binsA bins for histogram of dij from familiy A,
    #binsB bins for histogram of dij from familiy B,
    #binsC bins for histogram of dij from A-B co-MSA,
    #y_max is the the upper bound for y-axis.

    #---------------------------------------------------------------------------------------
    # Reads data sampled by ArDCA with the following fields:
    #numbered alignment for protA
    alignA_Num = h5read(inputsample, "seqsA")
    alignA_Num = convert(Matrix{Int8}, alignA_Num)
    La, Ma = size(alignA_Num)
    #numbered alignment for protB
    alignB_Num = h5read(inputsample, "seqsB")
    alignB_Num = convert(Matrix{Int8}, alignB_Num)
    Lb, Mb = size(alignB_Num)
    #list of interactions
    interaction_map = h5read(inputsample, "interactions")

    #---------------------------------------------------------------------------------------
    # Builds a co-MSA using the interaction map.
    L = La + Lb
    M = max(Ma, Mb)
    seqs_gen = Array{Int8,2}(undef, L, M)
    for i = 1:M
        seqs_gen[1:La,i] = alignA_Num[:, interaction_map[i,1]]    
        seqs_gen[La+1:L,i] = alignB_Num[:, interaction_map[i,2]]
    end
    
    #---------------------------------------------------------------------------------------
    # Computes pairwise Hamming distances.    	
    dij_A = Distances.pairwise(Hamming(), alignA_Num, dims = 2)
    dij_B = Distances.pairwise(Hamming(), alignB_Num, dims = 2)
    dij_gen = Distances.pairwise(Hamming(), seqs_gen, dims = 2)
    
    #---------------------------------------------------------------------------------------
    # Vectorizes pairwise Hamming distances.
    vec_dij_A = vectorize_mat(dij_A, Ma)
    vec_dij_A = vec_dij_A./La
    vec_dij_B = vectorize_mat(dij_B, Mb)
    vec_dij_B = vec_dij_B./Lb
    vec_dij_gen = vectorize_mat(dij_gen, M)
    vec_dij_gen = vec_dij_gen./L
    
    #------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    #Plots pairwise Hamming distances 'dij'.

    figure(figsize=(7,7))
    #dij A
    PyPlot.hist(vec_dij_A, bins=binsA, density=1, color="red", histtype="step", label="HK")
    PyPlot.hist(vec_dij_B, bins=binsB, density=1, color="blue", histtype="step", label="RR")
    PyPlot.hist(vec_dij_gen, bins=binsC, density=1, color="black", histtype="step", label="HK-RR")
    xscale("log")
    xlim(0,1)
    xticks(fontsize = 14)
    xlabel(string("Hamming distance", L"d_{ij}"), fontsize = 14)
    yscale("log")
    ylim(0,y_max)
    yticks(fontsize = 14)
    ylabel("Normalized number of sequences", fontsize = 14)
    legend(fontsize = 14, loc=2)
    PyPlot.savefig(string(figoutput, "_histogram_dij.pdf"), bbox_inches="tight")

end



#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
"""
	'Cijk_fig_generative'
Plots the comparison between natural sequences and samples from ArDCA model for the
three-site connected correlations 'Cijk(a, b, c)':

* 'inputnat': input fasta file for natural co-MSA data,
* 'inputsample': input H5DF file with sampled co-MSA data, 
* 'figoutput': output pdf file with figure.

The keyword arguments for the histogram with their default value:

* 'n_triplets'=140000 is the amount of triplets to take from all possible triplets,
* 'sim_threshold'=0.3 is the similarity threshold,
* 'max_gap_fraction'=0.9 is the maximum fraction of gaps in the sequences.

Example of use:

inputnat = "./data/HKa-RRa_for_arDCA.fasta"
inputsample = "./data/HK-RR_ArDCA_Natural_1to1_M=10000.h5"
figoutput = "./HK-RR_ArDCA_Natural_1to1"
Cijk_fig_generative(inputnat, inputsample, figoutput)
"""

function Cijk_fig_generative(inputnat::String, 
                inputsample::String, 
                figoutput::String; 
                n_triplets=140000::Int64,
                sim_threshold=0.3::Float64,
                max_gap_fraction::Real=0.9)

    #inputnat input fasta file for natural co-MSA data,
    #inputsample input H5DF file with sampled co-MSA data, 
    #figoutput output pdf file with figure.
    #n_triplets is the amount of triplets to take from all possible triplets,
    #sim_threshold is the similarity threshold,
    #max_gap_fraction is the maximum fraction of gaps in the sequences.

    #---------------------------------------------------------------------------------------
    # Parses a FASTA files containing MSAs for natural sequences, and returns a matrix...
    #...of integers that represents one sequence per column. If a sequence contains...
    #...a fraction of gaps that exceeds `max_gap_fraction`, it is discarded.    
    
    seqs_nat = read_fasta_alignment(inputnat, max_gap_fraction)
    
    #---------------------------------------------------------------------------------------
    # Reads data sampled by ArDCA with the following fields:
    #numbered alignment for protA
    alignA_Num = h5read(inputsample, "seqsA")
    alignA_Num = convert(Matrix{Int8}, alignA_Num)
    La, Ma = size(alignA_Num)
    #numbered alignment for protB
    alignB_Num = h5read(inputsample, "seqsB")
    alignB_Num = convert(Matrix{Int8}, alignB_Num)
    Lb, Mb = size(alignB_Num)
    #list of interactions
    interaction_map = h5read(inputsample, "interactions")

    #---------------------------------------------------------------------------------------
    # Builds a co-MSA using the interaction map.
    L = La + Lb
    M = max(Ma, Mb)
    seqs_gen = Array{Int8,2}(undef, L, M)
    for i = 1:M
        seqs_gen[1:La,i] = alignA_Num[:, interaction_map[i,1]]    
        seqs_gen[La+1:L,i] = alignB_Num[:, interaction_map[i,2]]
    end
    
    #---------------------------------------------------------------------------------------
    # Compute the reweighting vector. `sim_threshold` is the distance threshold.    
    w_nat, _ = compute_weights(seqs_nat, sim_threshold)
    w_gen, _ = compute_weights(seqs_gen, sim_threshold)
    
    #---------------------------------------------------------------------------------------
    # One hot encoding.
    data_nat = oneHotEncoding(seqs_nat)
    data_gen = oneHotEncoding(seqs_gen)
    q, L, M = size(data_nat)
    
    #---------------------------------------------------------------------------------------
    # Computes fi and fij for natural and generated sequences
    Pi_nat, Pij_nat = compute_weighted_frequencies(seqs_nat, w_nat, q+1)
    Pi_gen, Pij_gen = compute_weighted_frequencies(seqs_gen, w_gen, q+1)
    
    #---------------------------------------------------------------------------------------
    # Generates triplets
    triplets = createTriplets(L, n_triplets)
    
    #---------------------------------------------------------------------------------------
    #Divides triplets into small blocks of 'len_blocks' triplets and loop over them
    
    vec_cijk_nat = []
    vec_cijk_gen = []
    #check number of triplets
    if n_triplets >= L^3
        n_triplets = L^3
    end
    #compute number of blocks
    len_blocks = 10000
    n_blocks = ceil(Int, n_triplets/len_blocks)
    #loop over blocks
    for i = 1:n_blocks
        #---------------------------------------------------------------------------------------
        #indices for triplets
        triplets_ind = (i - 1) * len_blocks + 1:min(i * len_blocks, n_triplets)
        #---------------------------------------------------------------------------------------
        #Vectorize 'Cijk'
        vec_cijk_nat1 = computeCijk(data_nat, w_nat, Pi_nat, Pij_nat, triplets[triplets_ind])
        vec_cijk_gen1 = computeCijk(data_gen, w_gen, Pi_gen, Pij_gen, triplets[triplets_ind])
        #---------------------------------------------------------------------------------------
        #find indexes to remove (small couplings)
        n_nat1 = length(vec_cijk_nat1)
        n_gen1 = length(vec_cijk_gen1)
        println((n_nat1,n_gen1))
        filtered_vector_nat = [i for i = 1:n_nat1 if vec_cijk_nat1[i] < 0.003 && vec_cijk_nat1[i] > -0.003]
        filtered_vector_gen = [i for i = 1:n_gen1 if vec_cijk_gen1[i] < 0.003 && vec_cijk_gen1[i] > -0.003];
        filtered_vector = intersect(filtered_vector_nat, filtered_vector_gen);
        #
        println(length(vec_cijk_nat1))
        println("block = ", i, ", nat = ", length(filtered_vector_nat), ", gen = ", length(filtered_vector_gen), ", intersec = ", length(filtered_vector))
        #---------------------------------------------------------------------------------------
        #remove small 'Cijk' correlations
        deleteat!(vec_cijk_nat1, filtered_vector)
        deleteat!(vec_cijk_gen1, filtered_vector)        
        #---------------------------------------------------------------------------------------
        #keep 'larger' correlations
        vec_cijk_nat = vcat(vec_cijk_nat, vec_cijk_nat1)
        vec_cijk_gen = vcat(vec_cijk_gen, vec_cijk_gen1)
        GC.gc()
    end

    #---------------------------------------------------------------------------------------
    #Linear fit between 'Cijk' for natural and generated sequences.    
    n,m = linear_fit(vec_cijk_nat, vec_cijk_gen)
    println("linear fit:", (n,m))

    #---------------------------------------------------------------------------------------
    # Computes Pearson correlation between 'Cijk' for natural and generated sequences.
    r = cor(vec_cijk_nat, vec_cijk_gen)
    
    #------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    # Plots three-point correlations 'Cijk' of natural sequences vs 'Cijk' for generated ones.

    figure(figsize=(7,7))
    PyPlot.scatter(vec_cijk_nat, vec_cijk_gen, label="arDCA Pearson: $(round(r; digits=2)) \n Slope = $(round(m; digits=2))", marker="o", s=15, color="blue", alpha=0.5)
    line_reference = collect(range(start=-1.0,stop=1.0,step=0.01))
    PyPlot.plot(line_reference, line_reference, color="black", linestyle="dashed", linewidth=1)
    xlim(-0.1,0.1)
    xticks([-0.10,-0.08,-0.06,-0.04,-0.02,0.0,0.02,0.04,0.06,0.08,0.10], fontsize = 14)
    xlabel("\$C_{ijk}\$ Natural", fontsize = 18)
    ylim(-0.1,0.1)
    yticks([-0.10,-0.08,-0.06,-0.04,-0.02,0.0,0.02,0.04,0.06,0.08,0.10], fontsize = 14)
    ylabel("\$C_{ijk}\$ Sample", fontsize = 18)
    legend(fontsize = 14)
    PyPlot.savefig(string(figoutput, "_Cijk_generative.pdf"), bbox_inches="tight")
    
end




#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
"""
	'Cij_fig_generative'
Plots the comparison between natural sequences and samples from ArDCA model for the
two-site connected correlations 'Cij(a, b)':

* 'inputnat': input fasta file for natural co-MSA data,
* 'inputsample': input H5DF file with sampled co-MSA data, 
* 'figoutput': output pdf file with figure.

The keyword arguments for the histogram with their default value:

* 'sim_threshold'=0.3 is the similarity threshold,
* 'max_gap_fraction'=0.9 is the maximum fraction of gaps in the sequences.

Example of use:

inputnat = "./data/HKa-RRa_for_arDCA.fasta"
inputsample = "./data/HK-RR_ArDCA_Natural_1to1_M=10000.h5"
figoutput = "./HK-RR_ArDCA_Natural_1to1"
Cij_fig_generative(inputnat, inputsample, figoutput)
"""

function Cij_fig_generative(inputnat::String, 
                inputsample::String, 
                figoutput::String;
                sim_threshold=0.3::Float64,
                max_gap_fraction::Real=0.9)

    #---------------------------------------------------------------------------------------
    #Parses a FASTA files containing MSAs for natural sequences, and returns a matrix...
    #...of integers that represents one sequence per column. If a sequence contains...
    #...a fraction of gaps that exceeds `max_gap_fraction`, it is discarded.    
    
    seqs_nat = read_fasta_alignment(inputnat, max_gap_fraction)
    
    #---------------------------------------------------------------------------------------
    # Reads data sampled by ArDCA with the following fields:
    #numbered alignment for protA
    alignA_Num = h5read(inputsample, "seqsA")
    alignA_Num = convert(Matrix{Int8}, alignA_Num)
    La, Ma = size(alignA_Num)
    #numbered alignment for protB
    alignB_Num = h5read(inputsample, "seqsB")
    alignB_Num = convert(Matrix{Int8}, alignB_Num)
    Lb, Mb = size(alignB_Num)
    #list of interactions
    interaction_map = h5read(inputsample, "interactions")

    #---------------------------------------------------------------------------------------
    # Builds a co-MSA using the interaction map.
    L = La + Lb
    M = max(Ma, Mb)
    seqs_gen = Array{Int8,2}(undef, L, M)
    for i = 1:M
        seqs_gen[1:La,i] = alignA_Num[:, interaction_map[i,1]]    
        seqs_gen[La+1:L,i] = alignB_Num[:, interaction_map[i,2]]
    end
    
    #---------------------------------------------------------------------------------------
    # Computes the reweighting vector. 'Meff' is omitted. `sim_threshold` is the distance threshold.    
    w_nat, _ = compute_weights(seqs_nat, sim_threshold)
    w_gen, _ = compute_weights(seqs_gen, sim_threshold)
    
    #---------------------------------------------------------------------------------------
    # Computes fi and fij for natural and generated sequences    
    Pi_nat, Pij_nat = compute_weighted_frequencies(seqs_nat, w_nat)
    Pi_gen, Pij_gen = compute_weighted_frequencies(seqs_gen, w_gen)

    #---------------------------------------------------------------------------------------
    # Computes two-point correlation matrices    
    Cij_nat = Pij_nat - Pi_nat * Pi_nat'
    Cij_gen = Pij_gen - Pi_gen * Pi_gen'
    GC.gc()
    
    #---------------------------------------------------------------------------------------
    # Vectorizes correlation matrices
    vectCij_nat = vec(Cij_nat)
    vectCij_gen = vec(Cij_gen)
    GC.gc()

    #---------------------------------------------------------------------------------------
    # Linear fit between 'Cij' for natural and generated sequences.
    n,m = linear_fit(vectCij_nat, vectCij_gen)
    println("linear fit:", (n,m))

    #---------------------------------------------------------------------------------------
    # Computes Pearson correlation between 'Cij' for natural and generated sequences.
    r = cor(vectCij_nat, vectCij_gen)

    #------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    # Plots two-point correlations 'Cij' of natural sequences vs 'Cij' for generated ones.

    figure(figsize=(7,7))
    PyPlot.scatter(vectCij_nat, vectCij_gen, label="Pearson: $(round(r; digits=2)) \n Slope = $(round(m; digits=2))", marker="o", s=15, color="blue", alpha=0.5)
    line_reference = collect(range(start=-1.0,stop=1.0,step=0.01))
    PyPlot.plot(line_reference, line_reference, color="black", linestyle="dashed", linewidth=1)
    xlim(-0.3, 0.3)
    xticks(fontsize = 14)
    xlabel("\$C_{ij}\$ Natural", fontsize = 18)
    ylim(-0.3,0.3)
    yticks(fontsize = 14)
    ylabel("\$C_{ij}\$ Sample", fontsize = 18)
    legend(fontsize = 14)
    PyPlot.savefig(string(figoutput, "_Cij_generative.pdf"), bbox_inches="tight")

end




#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
"""
	'fi_fig_generative'
Plots the comparison between natural sequences and samples from ArDCA model for the
one-point frequenties 'fi(a)':

* 'inputnat': input fasta file for natural co-MSA data,
* 'inputsample': input H5DF file with sampled co-MSA data, 
* 'figoutput': output pdf file with figure.

The keyword arguments for the histogram with their default value:

* 'sim_threshold'=0.3 is the similarity threshold,
* 'max_gap_fraction'=0.9 is the maximum fraction of gaps in the sequences.

Example of use:

inputnat = "./data/HKa-RRa_for_arDCA.fasta"
inputsample = "./data/HK-RR_ArDCA_Natural_1to1_M=10000.h5"
figoutput = "./HK-RR_ArDCA_Natural_1to1"
fi_fig_generative(inputnat, inputsample, figoutput)
"""

function fi_fig_generative(inputnat::String, 
                inputsample::String, 
                figoutput::String; 
                sim_threshold=0.3::Float64,
                max_gap_fraction::Real=0.9)

    #---------------------------------------------------------------------------------------
    # Parses a FASTA files containing MSAs for natural sequences, and returns a matrix...
    #...of integers that represents one sequence per column. If a sequence contains...
    #...a fraction of gaps that exceeds `max_gap_fraction`, it is discarded.    
    
    seqs_nat = read_fasta_alignment(inputnat, max_gap_fraction)
    
    #---------------------------------------------------------------------------------------
    # Reads data sampled by ArDCA with the following fields:
    #numbered alignment for protA
    alignA_Num = h5read(inputsample, "seqsA")
    alignA_Num = convert(Matrix{Int8}, alignA_Num)
    La, Ma = size(alignA_Num)
    #numbered alignment for protB
    alignB_Num = h5read(inputsample, "seqsB")
    alignB_Num = convert(Matrix{Int8}, alignB_Num)
    Lb, Mb = size(alignB_Num)
    #list of interactions
    interaction_map = h5read(inputsample, "interactions")

    #---------------------------------------------------------------------------------------
    # Builds a co-MSA using the interaction map.
    L = La + Lb
    M = max(Ma, Mb)
    seqs_gen = Array{Int8,2}(undef, L, M)
    for i = 1:M
        seqs_gen[1:La,i] = alignA_Num[:, interaction_map[i,1]]    
        seqs_gen[La+1:L,i] = alignB_Num[:, interaction_map[i,2]]
    end
 
    #---------------------------------------------------------------------------------------
    # Computes the reweighting vector. 'Meff' is omitted. `sim_threshold` is the distance threshold.
    
    w_nat, _ = compute_weights(seqs_nat, sim_threshold)
    w_gen, _ = compute_weights(seqs_gen, sim_threshold)
    GC.gc()
    
    #---------------------------------------------------------------------------------------
    # Computes fi and fij for natural and generated sequences    
    Pi_nat, Pij_nat = compute_weighted_frequencies(seqs_nat, w_nat)
    Pi_gen, Pij_gen = compute_weighted_frequencies(seqs_gen, w_gen)
    GC.gc()

    #---------------------------------------------------------------------------------------
    # Vectorizes one-point frequencies.
    vectPi_nat = vec(Pi_nat)
    vectPi_gen = vec(Pi_gen)

    #---------------------------------------------------------------------------------------
    # Linear fit between 'fi' for natural and generated sequences.
    n,m = linear_fit(vectPi_nat, vectPi_gen)
    println("linear fit:", (n,m))

    #---------------------------------------------------------------------------------------
    # Computes Pearson correlation for 'fi' for natural and generated sequences.
    r = cor(vectPi_nat, vectPi_gen)

    #------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    # Plots one-point frequencies 'fi' of natural sequences vs 'fi' for generated ones.

    figure(figsize=(7,7))
    PyPlot.scatter(vectPi_nat, vectPi_gen, label="Pearson: $(round(r; digits=2)) \n Slope = $(round(m; digits=2))", marker="o", s=15, color="blue", alpha=0.5)
    line_reference = collect(range(start=0.0,stop=1.0,step=0.01))
    PyPlot.plot(line_reference, line_reference, color="black", linestyle="dashed", linewidth=1)
    xlim(0,1)
	xticks(fontsize = 14)
	xlabel("\$f_{i}\$ Natural", fontsize = 18)
	xlim(0,1)
	yticks(fontsize = 14)
 	ylabel("\$f_{i}\$ Sample", fontsize = 18)
	legend(fontsize = 14)
	fname = string(figoutput, "_Pi_generative.pdf")
	PyPlot.savefig(fname, bbox_inches="tight")

end







